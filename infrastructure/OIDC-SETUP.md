# 🔑 Configurar el rol OIDC para GitHub Actions

Este documento detalla el único paso de infraestructura que **no** gestiona
Terraform: el rol IAM que GitHub Actions asume para autenticarse contra AWS
sin claves de acceso estáticas.

## Por qué es manual

El workflow de CI/CD necesita permisos en AWS para poder ejecutar
`terraform apply`. Pero ese propio permiso no puede crearlo el workflow —
sería darle a un proceso la capacidad de auto-concederse acceso. Por eso
este rol se crea una única vez, con tus credenciales de administrador,
antes de la primera ejecución del pipeline.

Elige uno de los dos métodos de abajo (CLI o consola); el resultado es
idéntico. Necesitas AWS CLI configurado con un usuario/rol con permisos de
administrador, y saber tu `<AWS_ACCOUNT_ID>` (`aws sts get-caller-identity`)
y tu ruta de repositorio en GitHub (`<tu-usuario>/<tu-repo>`, ej.
`ccleren/docker-ecs-fargate-ec2`).

---

## Opción A — AWS CLI

### 1. Crear el proveedor OIDC de GitHub

Si tu cuenta de AWS ya tiene configurado el proveedor
`token.actions.githubusercontent.com` (es habitual si usas GitHub Actions
en otros proyectos), sáltate este paso.

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. Crear la trust policy

```bash
cat > trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<tu-usuario>/<tu-repo>:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF
```

Sustituye `<AWS_ACCOUNT_ID>` y `<tu-usuario>/<tu-repo>`. El `sub` acotado a
`ref:refs/heads/main` es deliberado: solo la rama `main` puede asumir el
rol, ni pull requests ni otras ramas.

### 3. Crear el rol

```bash
aws iam create-role \
  --role-name cloudpulse-github-actions \
  --assume-role-policy-document file://trust-policy.json \
  --description "Rol asumido por GitHub Actions (OIDC) para desplegar CloudPulse"
```

### 4. Adjuntar los permisos

Guarda la policy de abajo (sección [Permisos necesarios](#permisos-necesarios))
como `deploy-policy.json` y adjúntala:

```bash
aws iam put-role-policy \
  --role-name cloudpulse-github-actions \
  --policy-name cloudpulse-deploy \
  --policy-document file://deploy-policy.json
```

### 5. Copiar el ARN del rol

```bash
aws iam get-role --role-name cloudpulse-github-actions --query 'Role.Arn' --output text
```

Pega ese ARN en el secret `AWS_ROLE_ARN` del repositorio en GitHub
(**Settings → Secrets and variables → Actions → New repository secret**).

---

## Opción B — Consola de AWS

1. **IAM → Identity providers → Add provider**
   - Provider type: `OpenID Connect`
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`
   - Clic en **Get thumbprint** y luego **Add provider**.
   (Sáltate este paso si el proveedor ya existe en tu cuenta.)

2. **IAM → Roles → Create role**
   - Trusted entity type: `Web identity`
   - Identity provider: `token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`
   - En **GitHub organization** pon tu usuario; en **GitHub repository**
     pon el nombre del repo. Deja los campos de branch/tag como
     `Add condition` con `StringLike` sobre
     `token.actions.githubusercontent.com:sub` →
     `repo:<tu-usuario>/<tu-repo>:ref:refs/heads/main`.
   - Siguiente: en **Permissions**, clic en **Create policy** (se abre en
     pestaña nueva), pestaña **JSON**, pega el contenido de
     [Permisos necesarios](#permisos-necesarios), nómbrala
     `cloudpulse-deploy` y créala. Vuelve a la pestaña anterior y
     selecciónala en la lista.
   - Nombre del rol: `cloudpulse-github-actions`. Crear rol.

3. Abre el rol recién creado y copia su **ARN** (arriba a la derecha).
   Pégalo en el secret `AWS_ROLE_ARN` del repositorio en GitHub
   (**Settings → Secrets and variables → Actions → New repository secret**).

---

## Permisos necesarios

Política adjunta al rol — cubre todo lo que gestionan los 10 módulos de
Terraform (VPC, security groups, ALB, ECS, ECR, ACM, Route 53, CloudWatch,
IAM para los roles que crea `ecs-cluster`) más el acceso al backend remoto
(S3 + DynamoDB) y el `force-new-deployment` del pipeline:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformManagedServices",
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "elasticloadbalancing:*",
        "ecs:*",
        "ecr:*",
        "acm:*",
        "route53:*",
        "cloudwatch:*",
        "logs:*",
        "autoscaling:*",
        "application-autoscaling:*",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:PassRole",
        "iam:TagRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:GetInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile"
      ],
      "Resource": "*"
    },
    {
      "Sid": "TerraformRemoteState",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::cloudpulse-terraform-state",
        "arn:aws:s3:::cloudpulse-terraform-state/*"
      ]
    },
    {
      "Sid": "TerraformStateLock",
      "Effect": "Allow",
      "Action": ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"],
      "Resource": "arn:aws:dynamodb:*:*:table/cloudpulse-terraform-locks"
    }
  ]
}
```

> ⚠️ No es una política de mínimo privilegio estricta — usa acceso
> completo (`*`) sobre cada servicio para mantener el setup simple en un
> proyecto de portfolio. Para un uso en producción real, acótala por
> `Resource` (ARNs concretos de VPC/cluster/etc.) y reduce las acciones a
> las estrictamente necesarias por cada módulo.

Si cambiaste `state_bucket_name` o `lock_table_name` en
`infrastructure/bootstrap/variables.tf`, actualiza los ARNs de arriba en
consecuencia.

---

## Verificar que funciona

Desde la pestaña **Actions** del repositorio, ejecuta el workflow
manualmente (**Deploy CloudPulse → Run workflow**). Si el primer step
(`Configure AWS credentials`) pasa en verde, el rol está bien configurado.
