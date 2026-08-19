# 🖱️ CloudPulse de principio a fin — clic a clic / comando a comando

Esta guía es **puramente informativa**: construye todo el proyecto, desde
cero hasta tener las 3 apps sirviendo detrás del ALB, sin usar Terraform —
para entender exactamente qué hace cada pieza.

> ⚠️ **No es el método de despliegue real de este proyecto.** El repositorio
> se despliega con Terraform (`infrastructure/environments/prod`) y el
> workflow de CI/CD — ver [`README.md`](README.md) e
> [`infrastructure/README.md`](infrastructure/README.md). Si sigues esta
> guía y luego quieres traspasar la infraestructura a Terraform, tendrías
> que hacer `terraform import` de cada recurso. Úsala para entender el
> "por qué" de cada pieza, o para reconstruir una versión mínima de prueba
> sin tocar Terraform.

Cada paso incluye el camino de clics en la consola y el comando
equivalente de AWS CLI. Todos los comandos asumen la región `us-east-1`
— cámbiala si usas otra. Guarda cada ID que generes (VPC ID, subnet IDs,
ARNs...): los necesitarás en pasos posteriores.

---

## 0. Prerrequisitos

- Cuenta de AWS con permisos de administrador, AWS CLI configurado
  (`aws sts get-caller-identity` debe funcionar) y `<AWS_ACCOUNT_ID>` a mano.
- Docker instalado.
- Un dominio real que controles (para los pasos de Route 53 y ACM).
- Clona el repositorio:
  ```bash
  git clone https://github.com/ccleren/docker-ecs-fargate-ec2.git
  cd docker-ecs-fargate-ec2
  ```

---

## 1. Backend remoto (equivalente a `infrastructure/bootstrap`)

**Consola**: S3 → **Create bucket** → nombre único, ej.
`cloudpulse-terraform-state` → *Bucket Versioning*: Enable → *Default
encryption*: SSE-S3 → *Block all public access*: activado (por defecto).

DynamoDB → **Create table** → nombre `cloudpulse-terraform-locks` →
partition key `LockID` (String) → *Table class*: on-demand.

**CLI**:
```bash
aws s3api create-bucket --bucket cloudpulse-terraform-state --region us-east-1
aws s3api put-bucket-versioning --bucket cloudpulse-terraform-state \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket cloudpulse-terraform-state \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket cloudpulse-terraform-state \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws dynamodb create-table --table-name cloudpulse-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

> Si vas a usar Terraform de verdad más adelante, este paso es literalmente
> lo que hace `infrastructure/bootstrap`. Aquí no vuelve a usarse en el
> resto de la guía — es solo para dejar constancia de qué crea.

---

## 2. Red (VPC)

### 2.1 VPC

**Consola**: VPC → *Your VPCs* → **Create VPC** → "VPC only" → IPv4 CIDR
`10.0.0.0/16` → tras crearla, **Actions → Edit VPC settings** → habilita
*DNS hostnames* y *DNS resolution* → nombre `cloudpulse-vpc`.

**CLI**:
```bash
aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=cloudpulse-vpc}]'
aws ec2 modify-vpc-attribute --vpc-id <VPC_ID> --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id <VPC_ID> --enable-dns-support
```

### 2.2 DHCP Options Set

**Consola**: VPC → *DHCP option sets* → **Create DHCP option set** →
domain name `ec2.internal`, DNS servers `AmazonProvidedDNS` → tras
crearlo, en la VPC → **Actions → Edit DHCP options set** → selecciónalo.

**CLI**:
```bash
aws ec2 create-dhcp-options --dhcp-configurations \
  Key=domain-name,Values=ec2.internal Key=domain-name-servers,Values=AmazonProvidedDNS
aws ec2 associate-dhcp-options --dhcp-options-id <DHCP_OPTIONS_ID> --vpc-id <VPC_ID>
```

### 2.3 Subredes (2 públicas + 2 privadas, 2 AZs)

**Consola**: VPC → *Subnets* → **Create subnet**, repite 4 veces:

| Nombre | CIDR | AZ |
|---|---|---|
| `cloudpulse-public-us-east-1a` | `10.0.1.0/24` | us-east-1a |
| `cloudpulse-public-us-east-1b` | `10.0.2.0/24` | us-east-1b |
| `cloudpulse-private-us-east-1a` | `10.0.3.0/24` | us-east-1a |
| `cloudpulse-private-us-east-1b` | `10.0.4.0/24` | us-east-1b |

En las dos públicas: **Actions → Edit subnet settings** → activa
*Auto-assign public IPv4 address*.

**CLI** (repite con los otros 3 juegos de valores):
```bash
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=cloudpulse-public-us-east-1a}]'
aws ec2 modify-subnet-attribute --subnet-id <SUBNET_ID> --map-public-ip-on-launch
```

### 2.4 Internet Gateway

**Consola**: VPC → *Internet gateways* → **Create internet gateway** →
nombre `cloudpulse-igw` → **Actions → Attach to VPC**.

**CLI**:
```bash
aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=cloudpulse-igw}]'
aws ec2 attach-internet-gateway --internet-gateway-id <IGW_ID> --vpc-id <VPC_ID>
```

### 2.5 NAT Gateway

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

### 2.6 Route tables

**Consola**: VPC → *Route tables* → **Create route table** (pública) →
nombre `cloudpulse-public-rt` → **Edit routes** → añade `0.0.0.0/0` →
target = tu Internet Gateway → *Subnet associations* → asocia las 2
subredes públicas.

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

## 3. Security groups

**Consola**: EC2 → *Security groups* → **Create security group**, tres
veces:

- **`cloudpulse-alb-sg`** — inbound: TCP 80 desde `0.0.0.0/0`, TCP 443
  desde `0.0.0.0/0`.
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

## 4. ECR — repositorios de imágenes

**Consola**: ECR → *Repositories* → **Create repository**, tres veces
(`web`, `status`, `docs`):
- Visibility: Private · Tag immutability: **Enabled** · Scan on push:
  **Enabled** · Encryption: AES-256 (por defecto).

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

## 5. Build y push de las 3 imágenes Docker

Con los 3 repositorios ya creados, construye y sube cada app (`web`,
`status`, `docs`) desde la raíz del repositorio:

**No hay equivalente "clic en consola"** para este paso — construir
imágenes es intrínsecamente un comando, no una acción de la consola de AWS
(subirlas sí podrías hacerlo arrastrando un `.tar` desde algún sitio, pero
nadie lo hace así; el flujo real siempre es `docker build` + `docker push`).

```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

for service in web status docs; do
  docker build -t "$service" "./apps/$service"
  docker tag "$service:latest" "<AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/$service:latest"
  docker push "<AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/$service:latest"
done
```

Verifica que llegaron: ECR → cada repositorio → pestaña *Images* debe
mostrar el tag `latest`. O por CLI: `aws ecr list-images --repository-name web`.

---

## 6. Route 53 — hosted zone

Sáltate esto si ya tienes la hosted zone de tu dominio en Route 53.

**Consola**: Route 53 → *Hosted zones* → **Create hosted zone** → tu
dominio → tipo *Public hosted zone*. Copia los 4 *name servers* (tipo NS)
y configúralos en tu registrador de dominio.

**CLI**:
```bash
aws route53 create-hosted-zone --name tudominio.com --caller-reference "$(date +%s)"
```

---

## 7. ACM — certificado SSL

**Consola**: Certificate Manager (**en `us-east-1`**, el ALB solo acepta
certificados de esa región) → **Request certificate** → *Request a public
certificate* → dominio `cloudpulse.tudominio.com` → validación **DNS**.
Clic en **Create records in Route 53** (si la zona está en tu cuenta, AWS
rellena el registro de validación solo). Espera a que el estado pase a
*Issued*.

**CLI**:
```bash
aws acm request-certificate --domain-name cloudpulse.tudominio.com \
  --validation-method DNS --region us-east-1

aws acm describe-certificate --certificate-arn <CERT_ARN> --region us-east-1 \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord'

# Con el NAME/VALUE que devolvio el comando anterior:
aws route53 change-resource-record-sets --hosted-zone-id <ZONE_ID> --change-batch '{
  "Changes": [{"Action": "CREATE", "ResourceRecordSet": {
    "Name": "<NAME>", "Type": "CNAME", "TTL": 60,
    "ResourceRecords": [{"Value": "<VALUE>"}]
  }}]
}'
```

---

## 8. Application Load Balancer

### 8.1 Target groups (créalos antes que el ALB)

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

### 8.2 El ALB

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

### 8.3 Reglas de enrutamiento por path

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

### 8.4 Registro Alias en Route 53

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

## 9. IAM — roles de ECS

**Consola**: IAM → *Roles* → **Create role**:

- **`cloudpulse-ecs-instance-role`** — trusted entity: *AWS service* →
  *EC2* → adjunta la policy administrada
  `AmazonEC2ContainerServiceforEC2Role`.
- **`cloudpulse-ecs-task-execution-role`** — trusted entity: *AWS
  service* → *Elastic Container Service* → *Elastic Container Service
  Task* → adjunta `AmazonECSTaskExecutionRolePolicy` + una inline policy
  con `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`
  sobre `arn:aws:logs:*:*:*`.

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

## 10. ECS Cluster (EC2 + Fargate)

### 10.1 Launch template + Auto Scaling Group

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
in*.

**CLI**:
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

### 10.2 Cluster + Capacity Providers

**Consola**: ECS → *Clusters* → **Create cluster** → nombre
`cloudpulse-cluster` → *Infrastructure*: marca **Amazon EC2 instances**
(Auto Scaling Group `cloudpulse-ecs-asg`, Managed scaling *Enabled*,
target capacity `100`) **y** **AWS Fargate** → *Monitoring*: activa
**Container Insights**.

**CLI**:
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

## 11. CloudWatch — logs y alarmas

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

## 12. Task Definitions

**Consola**: ECS → *Task definitions* → **Create new task definition**,
tres veces (`webdef`, `statusdef` con *Launch type* EC2 / network mode
`bridge`; `docsdef` con *Launch type* Fargate / network mode `awsvpc`).
En cada una:
- Task execution role: `cloudpulse-ecs-task-execution-role`.
- CPU `0.5 vCPU` (512) · Memoria `1 GB` (1024).
- Contenedor: imagen = la URL de ECR del paso 5 + `:latest`, puerto
  contenedor `80` (en `webdef`/`statusdef` el *host port* déjalo en `0`).
- Logging: driver `awslogs`, log group = el creado en el paso 11, región
  `us-east-1`, stream prefix `ecs`.

**CLI** (ejemplo `webdef`; repite ajustando nombre/networkMode/
requiresCompatibilities/imagen para `statusdef` y `docsdef`):
```bash
aws ecs register-task-definition --family webdef \
  --requires-compatibilities EC2 --network-mode bridge \
  --cpu 512 --memory 1024 \
  --execution-role-arn <TASK_EXECUTION_ROLE_ARN> \
  --container-definitions '[{
    "name": "web",
    "image": "<AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/web:latest",
    "essential": true, "cpu": 512, "memory": 1024,
    "portMappings": [{"containerPort": 80, "hostPort": 0, "protocol": "tcp"}],
    "logConfiguration": {"logDriver": "awslogs", "options": {
      "awslogs-group": "/ecs/webdef", "awslogs-region": "us-east-1", "awslogs-stream-prefix": "ecs"
    }}
  }]'
```

---

## 13. ECS Services + autoescalado de servicio

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

## 14. Verificar que funciona

- Espera 1-2 minutos a que las tareas pasen a `RUNNING` y los target
  groups a `healthy` (EC2 → *Target groups* → pestaña *Targets*).
- Visita `https://cloudpulse.tudominio.com/` → debe cargar la landing
  (`web`).
- Visita `https://cloudpulse.tudominio.com/status/` → debe cargar la
  status page (`status`).
- Visita `https://cloudpulse.tudominio.com/docs/` → debe cargar la
  documentación (`docs`).
- Si algo da 503: revisa el estado de los targets en el target group
  correspondiente y los logs en CloudWatch (`/ecs/webdef`, etc.).

---

## 15. Y ahora, automatízalo

Si has llegado hasta aquí a mano, ya tienes claro qué hace cada pieza.
Bórralo todo (orden inverso: servicios → cluster/ASG → ALB → ACM →
Route 53 → ECR → security groups → VPC) y usa Terraform + GitHub Actions
para cualquier despliegue real:

1. [`infrastructure/README.md`](infrastructure/README.md) — el mismo
   resultado, con `terraform apply`, en unos pocos comandos.
2. [`infrastructure/OIDC-SETUP.md`](infrastructure/OIDC-SETUP.md) — el
   único paso que sigue siendo manual incluso con Terraform: el rol OIDC
   de GitHub Actions.

A partir de ahí, cada push dispara el pipeline
([`.github/workflows/deploy.yml`](.github/workflows/deploy.yml)) y hace
exactamente los pasos 5, 12, 13 y el `force-new-deployment` de esta guía,
automáticamente.
