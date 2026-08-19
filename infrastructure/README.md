# 🌍 Infraestructura — CloudPulse

Terraform de este proyecto, organizado en 3 capas:

- **`bootstrap/`** — backend remoto (bucket S3 + tabla DynamoDB). Se aplica
  una única vez, en local, con estado propio en disco. Ningún otro
  `terraform apply` del proyecto puede ejecutarse antes de este.
- **`modules/`** — 10 módulos reutilizables, uno por responsabilidad:
  `vpc`, `security-groups`, `ecr`, `ecs-cluster`, `ecs-task-definitions`,
  `ecs-services`, `alb`, `acm-certificate`, `route53`, `cloudwatch`.
- **`environments/prod/`** — el único environment desplegado por defecto;
  conecta los 10 módulos. La estructura deja hueco para futuros
  `environments/dev` o `environments/staging` reutilizando los mismos
  módulos con otro `.tfvars`.

¿Prefieres ver qué crea cada módulo pero clic a clic en la consola de AWS
en vez de en HCL? Está todo en
[`AWS-CONSOLE-WALKTHROUGH.md`](AWS-CONSOLE-WALKTHROUGH.md) — solo con
fines educativos, el despliegue real sigue siendo con Terraform.

## Orden de aplicación

Terraform resuelve el orden automáticamente por el grafo de dependencias
entre módulos, pero a alto nivel:

```
vpc, security-groups, ecr
        │
route53 (zona) ──▶ acm-certificate (validación DNS) ──▶ alb (certificado)
        ▲                                                    │
        └────────────────── route53 (registro Alias) ◀───────┘
        │
ecs-cluster ──▶ cloudwatch (log groups + alarmas)
        │
ecs-task-definitions ──▶ ecs-services (+ autoescalado de servicio)
```

`route53` aparece dos veces porque, dentro del mismo módulo, la zona (sin
dependencias) y el registro Alias (depende del ALB) son recursos distintos
— no hay ciclo real, Terraform lo resuelve a nivel de recurso.

---

## 🚀 Despliegue paso a paso

### 0. Prerrequisitos

- Cuenta de AWS con permisos de administrador (para el setup inicial).
- Un dominio real que controles, con capacidad de configurar sus DNS.
- Terraform >= 1.6, AWS CLI y Docker instalados.

### 1. Bootstrap del backend remoto

```bash
cd infrastructure/bootstrap
terraform init
terraform apply
```

Anota los outputs `state_bucket_name` y `lock_table_name`: deben coincidir
con los valores hardcodeados en `environments/prod/backend.tf` (Terraform
no admite variables dentro de un bloque `backend`).

### 2. Rol IAM para GitHub Actions (OIDC)

El pipeline asume un rol mediante OIDC — no usa claves de acceso estáticas. Ese
rol es la única pieza de infraestructura que **no** gestiona el Terraform
de este repositorio (problema de huevo y gallina: el pipeline no puede
crearse a sí mismo el permiso que necesita para correr). Se crea una única
vez, con tus credenciales de administrador, con la CLI o desde la consola.

Guía completa, con comandos y política IAM incluidos, en
[`OIDC-SETUP.md`](OIDC-SETUP.md).

### 3. Configurar variables

```bash
cd infrastructure/environments/prod
cp terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` con tu dominio real y, si aplica, ajusta
`create_hosted_zone`, tamaños de ASG/servicio y umbrales de alarmas.
`terraform.tfvars` está en `.gitignore`: nunca se sube al repositorio.

### 4. Desplegar infraestructura

```bash
terraform init
terraform plan
terraform apply
```

Si `create_hosted_zone = true`, este primer `apply` crea la hosted zone;
toma los name servers del output `route53_name_servers` y configúralos en
tu registrador de dominio antes de que la validación del certificado ACM
pueda completarse.

### 5. Build de las 3 apps y push a ECR

Lo hace el workflow de CI/CD ([`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml)),
disparado manualmente (`workflow_dispatch`) mientras el trigger automático
en push a `main` esté comentado. El equivalente manual está documentado en
la sección CI/CD del [README general](../README.md).

### 6. Force new deployment

```bash
aws ecs update-service --cluster cloudpulse-cluster --service web --force-new-deployment
aws ecs update-service --cluster cloudpulse-cluster --service status --force-new-deployment
aws ecs update-service --cluster cloudpulse-cluster --service docs --force-new-deployment
```

También lo hace el pipeline automáticamente tras cada `apply`.

---

## Añadir un microservicio nuevo

`infrastructure/` y `apps/` están desacopladas: un microservicio nuevo solo
necesita:

1. Una carpeta en `apps/<nombre>/` con `Dockerfile`, `default.conf` (nginx
   sirviendo en el puerto 80, con el prefijo de path correcto) y el
   contenido estático.
2. Un repositorio ECR nuevo — añade `<nombre>` a `repository_names` en la
   llamada al módulo `ecr` de `environments/prod/main.tf`.
3. Una entrada nueva en los mapas `task_definitions` (módulo
   `ecs-task-definitions`) y `services` (módulo `ecs-services`), y un
   target group + regla de enrutamiento nueva en el módulo `alb`.

No hace falta tocar ningún módulo existente para esto — todos están
parametrizados con `for_each` sobre mapas.
