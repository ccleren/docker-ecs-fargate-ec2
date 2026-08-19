# 🖱️ CloudPulse a mano, desde la consola de AWS

Este documento es **puramente educativo**: reconstruye, clic a clic en la
consola de AWS, exactamente lo que crean los 10 módulos de Terraform de
este repositorio — para entender qué hace `terraform apply` por debajo.

> ⚠️ **No es el método de despliegue real de este proyecto.** El repositorio
> se despliega con Terraform (`infrastructure/environments/prod`) y el
> workflow de CI/CD. Si sigues esta guía y luego quieres traspasar la
> infraestructura a Terraform, tendrías que hacer `terraform import` de cada
> recurso — no lo cubrimos aquí. Úsala para entender el "por qué" de cada
> pieza, o para reconstruir una versión mínima de prueba sin tocar Terraform.

Cada paso incluye el camino de clics en la consola **y** el comando
equivalente de AWS CLI, para que veas la correspondencia entre ambos.
Todos los comandos asumen la región `us-east-1` — cámbiala si usas otra.

---

## 0. Antes de empezar

- Ten a mano tu `<AWS_ACCOUNT_ID>` (esquina superior derecha de la consola,
  o `aws sts get-caller-identity`).
- Un dominio real que controles, si vas a completar los pasos de Route 53
  y ACM.
- Guarda cada ID que vayas generando (VPC ID, subnet IDs, SG IDs...): los
  necesitarás en pasos posteriores. En la CLI, casi todos los `create-*`
  devuelven el ID en la respuesta JSON.

---

## 1. VPC y red

### 1.1 VPC

**Consola**: VPC → *Your VPCs* → **Create VPC** → "VPC only" → IPv4 CIDR
`10.0.0.0/16` → habilita *DNS hostnames* y *DNS resolution* en la pestaña
de configuración tras crearla (**Actions → Edit VPC settings**) → nombre
`cloudpulse-vpc`.

**CLI**:
```bash
aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=cloudpulse-vpc}]'
aws ec2 modify-vpc-attribute --vpc-id <VPC_ID> --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id <VPC_ID> --enable-dns-support
```

### 1.2 DHCP Options Set

**Consola**: VPC → *DHCP option sets* → **Create DHCP option set** →
domain name `ec2.internal`, DNS servers `AmazonProvidedDNS` → tras
crearlo, VPC → *Your VPCs* → selecciona la VPC → **Actions → Edit DHCP
options set** → elige el que acabas de crear.

**CLI**:
```bash
aws ec2 create-dhcp-options --dhcp-configurations \
  Key=domain-name,Values=ec2.internal Key=domain-name-servers,Values=AmazonProvidedDNS
aws ec2 associate-dhcp-options --dhcp-options-id <DHCP_OPTIONS_ID> --vpc-id <VPC_ID>
```

### 1.3 Subredes (2 públicas + 2 privadas, 2 AZs)

**Consola**: VPC → *Subnets* → **Create subnet**, repite 4 veces:

| Nombre | CIDR | AZ |
|---|---|---|
| `cloudpulse-public-us-east-1a` | `10.0.1.0/24` | us-east-1a |
| `cloudpulse-public-us-east-1b` | `10.0.2.0/24` | us-east-1b |
| `cloudpulse-private-us-east-1a` | `10.0.3.0/24` | us-east-1a |
| `cloudpulse-private-us-east-1b` | `10.0.4.0/24` | us-east-1b |

En las dos públicas: selecciona la subred → **Actions → Edit subnet
settings** → activa *Auto-assign public IPv4 address*.

**CLI** (una de las 4, repite con los otros valores):
```bash
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=cloudpulse-public-us-east-1a}]'
aws ec2 modify-subnet-attribute --subnet-id <SUBNET_ID> --map-public-ip-on-launch
```

### 1.4 Internet Gateway

**Consola**: VPC → *Internet gateways* → **Create internet gateway** →
nombre `cloudpulse-igw` → selecciónalo → **Actions → Attach to VPC**.

**CLI**:
```bash
aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=cloudpulse-igw}]'
aws ec2 attach-internet-gateway --internet-gateway-id <IGW_ID> --vpc-id <VPC_ID>
```

### 1.5 NAT Gateway

**Consola**: VPC → *NAT gateways* → **Create NAT gateway** → subred =
`cloudpulse-public-us-east-1a` → *Connectivity type*: Public → **Allocate
Elastic IP** → nombre `cloudpulse-nat`.

**CLI**:
```bash
aws ec2 allocate-address --domain vpc
aws ec2 create-nat-gateway --subnet-id <PUBLIC_SUBNET_A_ID> \
  --allocation-id <EIP_ALLOCATION_ID> \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=cloudpulse-nat}]'
```

### 1.6 Route tables

**Consola**: VPC → *Route tables* → **Create route table** (pública) →
nombre `cloudpulse-public-rt` → *Routes* → **Edit routes** → añade
`0.0.0.0/0` → target = tu Internet Gateway → *Subnet associations* →
asocia las 2 subredes públicas.

Repite para la privada: `cloudpulse-private-rt`, ruta `0.0.0.0/0` → target
= tu NAT Gateway → asocia las 2 subredes privadas.

**CLI**:
```bash
aws ec2 create-route-table --vpc-id <VPC_ID> \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=cloudpulse-public-rt}]'
aws ec2 create-route --route-table-id <PUBLIC_RT_ID> \
  --destination-cidr-block 0.0.0.0/0 --gateway-id <IGW_ID>
aws ec2 associate-route-table --route-table-id <PUBLIC_RT_ID> --subnet-id <PUBLIC_SUBNET_A_ID>
aws ec2 associate-route-table --route-table-id <PUBLIC_RT_ID> --subnet-id <PUBLIC_SUBNET_B_ID>

aws ec2 create-route-table --vpc-id <VPC_ID> \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=cloudpulse-private-rt}]'
aws ec2 create-route --route-table-id <PRIVATE_RT_ID> \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id <NAT_GATEWAY_ID>
aws ec2 associate-route-table --route-table-id <PRIVATE_RT_ID> --subnet-id <PRIVATE_SUBNET_A_ID>
aws ec2 associate-route-table --route-table-id <PRIVATE_RT_ID> --subnet-id <PRIVATE_SUBNET_B_ID>
```

---

## 2. Security groups

**Consola**: EC2 → *Security groups* → **Create security group**, tres
veces:

- **`cloudpulse-alb-sg`** — inbound: TCP 80 desde `0.0.0.0/0`, TCP 443
  desde `0.0.0.0/0`. Outbound: todo (regla por defecto).
- **`cloudpulse-ecs-instance-sg`** — inbound: TCP 0-65535, source =
  security group `cloudpulse-alb-sg` (no un CIDR).
- **`cloudpulse-workstation-sg`** *(opcional)* — inbound: TCP 22 desde tu
  IP concreta, nunca `0.0.0.0/0`.

**CLI**:
```bash
aws ec2 create-security-group --group-name cloudpulse-alb-sg \
  --description "ALB traffic" --vpc-id <VPC_ID>
aws ec2 authorize-security-group-ingress --group-id <ALB_SG_ID> \
  --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id <ALB_SG_ID> \
  --protocol tcp --port 443 --cidr 0.0.0.0/0

aws ec2 create-security-group --group-name cloudpulse-ecs-instance-sg \
  --description "ECS traffic, only from ALB" --vpc-id <VPC_ID>
aws ec2 authorize-security-group-ingress --group-id <ECS_SG_ID> \
  --protocol tcp --port 0-65535 --source-group <ALB_SG_ID>
```

---

## 3. ECR — repositorios de imágenes

**Consola**: ECR → *Repositories* → **Create repository**, tres veces
(`web`, `status`, `docs`):
- Visibility: Private
- Tag immutability: **Enabled**
- Scan on push: **Enabled**
- Encryption: AES-256 (por defecto)

Tras crear cada uno: pestaña **Lifecycle policy** → **Create rule** →
"Expire images" → *Image count more than* `10` → *Any tags*.

**CLI** (repite `--repository-name` para `status` y `docs`):
```bash
aws ecr create-repository --repository-name web \
  --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256

aws ecr put-lifecycle-policy --repository-name web --lifecycle-policy-text '{
  "rules": [{
    "rulePriority": 1,
    "description": "Retener solo las ultimas 10 imagenes",
    "selection": {"tagStatus": "any", "countType": "imageCountMoreThan", "countNumber": 10},
    "action": {"type": "expire"}
  }]
}'
```

---

## 4. Route 53 — hosted zone

Sáltate esto si ya tienes la hosted zone de tu dominio en Route 53.

**Consola**: Route 53 → *Hosted zones* → **Create hosted zone** → tu
dominio → tipo *Public hosted zone*. Copia los 4 *name servers* (tipo NS)
y configúralos en tu registrador de dominio.

**CLI**:
```bash
aws route53 create-hosted-zone --name tudominio.com --caller-reference "$(date +%s)"
```

---

## 5. ACM — certificado SSL

**Consola**: Certificate Manager (**en `us-east-1`**, el ALB solo acepta
certificados de esa región) → **Request certificate** → *Request a public
certificate* → dominio `cloudpulse.tudominio.com` → validación **DNS**.
Tras crearlo, clic en **Create records in Route 53** (AWS rellena el
registro de validación automáticamente si la zona está en tu cuenta).
Espera a que el estado pase a *Issued* (unos minutos).

**CLI**:
```bash
aws acm request-certificate --domain-name cloudpulse.tudominio.com \
  --validation-method DNS --region us-east-1

# Consulta el registro CNAME de validacion que pide ACM:
aws acm describe-certificate --certificate-arn <CERT_ARN> --region us-east-1 \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord'

# Crealo en tu zona (sustituye NAME/VALUE por lo que devolvio el comando anterior):
aws route53 change-resource-record-sets --hosted-zone-id <ZONE_ID> --change-batch '{
  "Changes": [{"Action": "CREATE", "ResourceRecordSet": {
    "Name": "<NAME>", "Type": "CNAME", "TTL": 60,
    "ResourceRecords": [{"Value": "<VALUE>"}]
  }}]
}'
```

---

## 6. Application Load Balancer

### 6.1 Target groups (créalos antes que el ALB)

**Consola**: EC2 → *Target groups* → **Create target group**, tres veces:

| Target group | Target type | Health check path |
|---|---|---|
| `cloudpulse-web-tg` | Instances | `/` |
| `cloudpulse-status-tg` | Instances | `/status/` |
| `cloudpulse-docs-tg` | **IP addresses** | `/docs/` |

Protocolo HTTP, puerto 80, VPC = `cloudpulse-vpc` en los tres.

**CLI**:
```bash
aws elbv2 create-target-group --name cloudpulse-web-tg \
  --protocol HTTP --port 80 --vpc-id <VPC_ID> --target-type instance \
  --health-check-path /
# repite para status-tg (health-check-path /status/) y
# docs-tg (target-type ip, health-check-path /docs/)
```

### 6.2 El ALB

**Consola**: EC2 → *Load balancers* → **Create load balancer** →
Application Load Balancer → *Internet-facing* → subredes = las 2
públicas → security group = `cloudpulse-alb-sg`.

- Listener HTTP:80 → **Add action → Redirect to...** → HTTPS:443,
  código 301.
- Listener HTTPS:443 → certificado = el de ACM → *default action* →
  forward a `cloudpulse-web-tg`.

**CLI**:
```bash
aws elbv2 create-load-balancer --name cloudpulse-alb \
  --subnets <PUBLIC_SUBNET_A_ID> <PUBLIC_SUBNET_B_ID> \
  --security-groups <ALB_SG_ID> --scheme internet-facing --type application

aws elbv2 create-listener --load-balancer-arn <ALB_ARN> \
  --protocol HTTP --port 80 \
  --default-actions Type=redirect,RedirectConfig='{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}'

aws elbv2 create-listener --load-balancer-arn <ALB_ARN> \
  --protocol HTTPS --port 443 --certificates CertificateArn=<CERT_ARN> \
  --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06 \
  --default-actions Type=forward,TargetGroupArn=<WEB_TG_ARN>
```

### 6.3 Reglas de enrutamiento por path

**Consola**: selecciona el listener HTTPS:443 → **Manage rules → Add
rule**:
- Regla 1 (prioridad 1): *If* Path is `/status*` → *Then* forward a
  `cloudpulse-status-tg`.
- Regla 2 (prioridad 2): *If* Path is `/docs*` → *Then* forward a
  `cloudpulse-docs-tg`.

**CLI**:
```bash
aws elbv2 create-rule --listener-arn <HTTPS_LISTENER_ARN> --priority 1 \
  --conditions Field=path-pattern,Values='/status*' \
  --actions Type=forward,TargetGroupArn=<STATUS_TG_ARN>

aws elbv2 create-rule --listener-arn <HTTPS_LISTENER_ARN> --priority 2 \
  --conditions Field=path-pattern,Values='/docs*' \
  --actions Type=forward,TargetGroupArn=<DOCS_TG_ARN>
```

### 6.4 Registro Alias en Route 53

**Consola**: Route 53 → tu hosted zone → **Create record** → nombre =
tu dominio → tipo `A` → **Alias** → *Alias to Application Load Balancer* →
región `us-east-1` → selecciona `cloudpulse-alb`.

**CLI**:
```bash
aws route53 change-resource-record-sets --hosted-zone-id <ZONE_ID> --change-batch '{
  "Changes": [{"Action": "CREATE", "ResourceRecordSet": {
    "Name": "cloudpulse.tudominio.com", "Type": "A",
    "AliasTarget": {"HostedZoneId": "<ALB_ZONE_ID>", "DNSName": "<ALB_DNS_NAME>", "EvaluateTargetHealth": true}
  }}]
}'
```

---

## 7. IAM — roles de ECS

**Consola**: IAM → *Roles* → **Create role**:

- **`cloudpulse-ecs-instance-role`** — trusted entity: *AWS service* →
  *EC2* → adjunta la policy administrada
  `AmazonEC2ContainerServiceforEC2Role`. Tras crearlo, IAM → *Roles* →
  ábrelo → pestaña adicional no hace falta: EC2 lo usará como *instance
  profile* (la consola crea el instance profile automáticamente con el
  mismo nombre al asociarlo a una instancia/launch template).
- **`cloudpulse-ecs-task-execution-role`** — trusted entity: *AWS
  service* → *Elastic Container Service* → *Elastic Container Service
  Task* → adjunta `AmazonECSTaskExecutionRolePolicy` + una inline policy
  con permisos de `logs:CreateLogGroup`, `logs:CreateLogStream`,
  `logs:PutLogEvents` sobre `arn:aws:logs:*:*:*`.

**CLI**:
```bash
aws iam create-role --role-name cloudpulse-ecs-instance-role \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam attach-role-policy --role-name cloudpulse-ecs-instance-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role
aws iam create-instance-profile --instance-profile-name cloudpulse-ecs-instance-profile
aws iam add-role-to-instance-profile \
  --instance-profile-name cloudpulse-ecs-instance-profile \
  --role-name cloudpulse-ecs-instance-role

aws iam create-role --role-name cloudpulse-ecs-task-execution-role \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam attach-role-policy --role-name cloudpulse-ecs-task-execution-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

---

## 8. ECS Cluster (EC2 + Fargate)

### 8.1 Launch template + Auto Scaling Group

**Consola**: EC2 → *Launch templates* → **Create launch template** →
nombre `cloudpulse-ecs` → AMI: busca "Amazon ECS-Optimized Amazon Linux
2" → instance type `t2.medium` → IAM instance profile =
`cloudpulse-ecs-instance-profile` → security group =
`cloudpulse-ecs-instance-sg` → *Advanced details → User data*:

```
#!/bin/bash
echo ECS_CLUSTER=cloudpulse-cluster >> /etc/ecs/ecs.config
```

Luego EC2 → *Auto Scaling Groups* → **Create Auto Scaling group** → usa
el launch template → subredes = las 2 privadas → tamaño: min `2` /
max `4` / deseada `2` → en *Advanced options*, activa *Protect from scale
in* (lo necesita el Capacity Provider más adelante).

**CLI**: obtener el AMI ID vigente y crear ambos recursos.
```bash
AMI_ID=$(aws ssm get-parameter \
  --name /aws/service/ecs/optimized-ami/amazon-linux-2/recommended \
  --query 'Parameter.Value' --output text | jq -r '.image_id')

aws ec2 create-launch-template --launch-template-name cloudpulse-ecs \
  --launch-template-data "{
    \"ImageId\": \"$AMI_ID\", \"InstanceType\": \"t2.medium\",
    \"IamInstanceProfile\": {\"Name\": \"cloudpulse-ecs-instance-profile\"},
    \"SecurityGroupIds\": [\"<ECS_SG_ID>\"],
    \"UserData\": \"$(echo -e '#!/bin/bash\necho ECS_CLUSTER=cloudpulse-cluster >> /etc/ecs/ecs.config' | base64 -w0)\"
  }"

aws autoscaling create-auto-scaling-group --auto-scaling-group-name cloudpulse-ecs-asg \
  --launch-template LaunchTemplateName=cloudpulse-ecs,Version='$Latest' \
  --min-size 2 --max-size 4 --desired-capacity 2 \
  --vpc-zone-identifier "<PRIVATE_SUBNET_A_ID>,<PRIVATE_SUBNET_B_ID>" \
  --new-instances-protected-from-scale-in
```

### 8.2 Cluster + Capacity Providers

**Consola**: ECS → *Clusters* → **Create cluster** → nombre
`cloudpulse-cluster` → *Infrastructure*: marca **Amazon EC2 instances**
(elige el Auto Scaling Group `cloudpulse-ecs-asg`, Managed scaling
*Enabled*, target capacity `100`) **y** **AWS Fargate** → *Monitoring*:
activa **Container Insights**.

**CLI** (la consola simplifica varios pasos; con la CLI se crean por
separado):
```bash
aws ecs put-account-setting --name containerInsights --value enabled

aws ecs create-capacity-provider --name cloudpulse-ec2-cp \
  --auto-scaling-group-provider "autoScalingGroupArn=<ASG_ARN>,managedScaling={status=ENABLED,targetCapacity=100},managedTerminationProtection=ENABLED"

aws ecs create-cluster --cluster-name cloudpulse-cluster \
  --settings name=containerInsights,value=enabled \
  --capacity-providers cloudpulse-ec2-cp FARGATE \
  --default-capacity-provider-strategy capacityProvider=cloudpulse-ec2-cp,weight=1
```

---

## 9. CloudWatch — logs y alarmas

**Consola**: CloudWatch → *Log groups* → **Create log group**, tres veces:
`/ecs/webdef`, `/ecs/statusdef`, `/ecs/docsdef` → retención 30 días.

Luego *Alarms* → **Create alarm**, dos veces:
- Métrica `AWS/ECS → ClusterName=cloudpulse-cluster → CPUUtilization`,
  condición *Greater than* `80`, 3 periodos de 1 minuto.
- Igual pero con `MemoryUtilization`.

**CLI**:
```bash
for lg in /ecs/webdef /ecs/statusdef /ecs/docsdef; do
  aws logs create-log-group --log-group-name "$lg"
  aws logs put-retention-policy --log-group-name "$lg" --retention-in-days 30
done

aws cloudwatch put-metric-alarm --alarm-name cloudpulse-cluster-cpu-high \
  --namespace AWS/ECS --metric-name CPUUtilization --statistic Average \
  --dimensions Name=ClusterName,Value=cloudpulse-cluster \
  --comparison-operator GreaterThanThreshold --threshold 80 \
  --evaluation-periods 3 --period 60

aws cloudwatch put-metric-alarm --alarm-name cloudpulse-cluster-memory-high \
  --namespace AWS/ECS --metric-name MemoryUtilization --statistic Average \
  --dimensions Name=ClusterName,Value=cloudpulse-cluster \
  --comparison-operator GreaterThanThreshold --threshold 80 \
  --evaluation-periods 3 --period 60
```

---

## 10. Task Definitions

**Consola**: ECS → *Task definitions* → **Create new task definition**,
tres veces (`webdef`, `statusdef` con *Launch type* EC2 / network mode
`bridge`; `docsdef` con *Launch type* Fargate / network mode `awsvpc`).
En cada una:
- Task role: (ninguno necesario para este demo) · Task execution role:
  `cloudpulse-ecs-task-execution-role`.
- CPU `0.5 vCPU` (512) · Memoria `1 GB` (1024).
- Contenedor: imagen = tu URL de ECR + `:latest`, puerto contenedor `80`
  (en `webdef`/`statusdef` el *host port* déjalo en `0`, dinámico).
- Logging: driver `awslogs`, log group = el correspondiente creado en el
  paso 9, región `us-east-1`, stream prefix `ecs`.

**CLI** (ejemplo para `webdef`; repite ajustando nombre/networkMode/
requiresCompatibilities para `statusdef` y `docsdef`):
```bash
aws ecs register-task-definition --family webdef \
  --requires-compatibilities EC2 --network-mode bridge \
  --cpu 512 --memory 1024 \
  --execution-role-arn <TASK_EXECUTION_ROLE_ARN> \
  --container-definitions '[{
    "name": "web",
    "image": "<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/web:latest",
    "essential": true, "cpu": 512, "memory": 1024,
    "portMappings": [{"containerPort": 80, "hostPort": 0, "protocol": "tcp"}],
    "logConfiguration": {"logDriver": "awslogs", "options": {
      "awslogs-group": "/ecs/webdef", "awslogs-region": "us-east-1", "awslogs-stream-prefix": "ecs"
    }}
  }]'
```

---

## 11. ECS Services + autoescalado de servicio

**Consola**: ECS → tu cluster → *Services* → **Create**, tres veces:
- `web` / `status`: launch type EC2, task definition correspondiente,
  desired tasks `2`, load balancer = ALB existente, target group =
  `cloudpulse-web-tg` / `cloudpulse-status-tg`, container = puerto 80.
- `docs`: launch type Fargate, subredes privadas, security group
  `cloudpulse-ecs-instance-sg`, target group `cloudpulse-docs-tg`.

En cada servicio, pestaña *Auto Scaling* → **Configure Service Auto
Scaling** → min `2` / max `8` → *Target tracking* → métrica
`ALBRequestCountPerTarget` → valor objetivo `1000` → scale-out cooldown
`10s` / scale-in cooldown `300s`.

**CLI** (ejemplo `web`; `status` es análogo; `docs` cambia
`--launch-type FARGATE` + `--network-configuration`):
```bash
aws ecs create-service --cluster cloudpulse-cluster --service-name web \
  --task-definition webdef --desired-count 2 \
  --capacity-provider-strategy capacityProvider=cloudpulse-ec2-cp,weight=1 \
  --load-balancers targetGroupArn=<WEB_TG_ARN>,containerName=web,containerPort=80

aws application-autoscaling register-scalable-target \
  --service-namespace ecs --scalable-dimension ecs:service:DesiredCount \
  --resource-id service/cloudpulse-cluster/web --min-capacity 2 --max-capacity 8

aws application-autoscaling put-scaling-policy --policy-name web-request-count-tracking \
  --service-namespace ecs --scalable-dimension ecs:service:DesiredCount \
  --resource-id service/cloudpulse-cluster/web --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 1000, "ScaleOutCooldown": 10, "ScaleInCooldown": 300,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ALBRequestCountPerTarget",
      "ResourceLabel": "<ALB_ARN_SUFFIX>/<WEB_TG_ARN_SUFFIX>"
    }
  }'
```

---

## Y ahora, olvídalo

Si has llegado hasta aquí a mano, ya tienes clara la mecánica de cada
pieza. Bórralo todo (en orden inverso: servicios → cluster/ASG → ALB →
ACM → Route 53 → ECR → security groups → VPC) y usa Terraform para
cualquier cosa real — es exactamente para evitar repetir estos ~40 pasos
manuales, sin margen de error de tipeo, para lo que existe
`infrastructure/environments/prod`.
