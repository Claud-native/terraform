# 🚀 Instrucciones de Despliegue - EduCloud en AWS

## 📋 Índice
1. [Resumen de Arquitectura](#resumen-de-arquitectura)
2. [Archivos Creados](#archivos-creados)
3. [Pre-requisitos](#pre-requisitos)
4. [Pasos de Despliegue](#pasos-de-despliegue)
5. [Configuración Post-Despliegue](#configuración-post-despliegue)
6. [Comandos Útiles](#comandos-útiles)
7. [Troubleshooting](#troubleshooting)

---

## 🏗️ Resumen de Arquitectura

```
┌────────────────────────────────────────────────────────────────────┐
│                         AWS Cloud (us-east-1)                      │
│                                                                    │
│  Internet                                                          │
│      │                                                             │
│      ▼                                                             │
│  ┌─────────────┐                                                  │
│  │     WAF     │ ◄─── Protección DDoS, SQL Injection             │
│  └──────┬──────┘                                                  │
│         │                                                          │
│         ▼                                                          │
│  ┌─────────────┐                                                  │
│  │     ALB     │ ◄─── Load Balancer (HTTP/HTTPS)                 │
│  │  (2x AZs)   │                                                  │
│  └──────┬──────┘                                                  │
│         │                                                          │
│    ┌────┴────┬────────┐                                          │
│    │         │        │                                           │
│    ▼         ▼        ▼                                           │
│  ┌─────┐  ┌─────┐  ┌─────┐                                      │
│  │ ECS │  │ ECS │  │ ECS │ ◄─── 3x Fargate Tasks (Backend)      │
│  │  1  │  │  2  │  │  3  │       (Auto-scaling 3-10)            │
│  └──┬──┘  └──┬──┘  └──┬──┘                                      │
│     │        │        │                                           │
│     └────────┴────────┘                                           │
│              │                                                     │
│              ▼                                                     │
│  ┌────────────────────────┐                                      │
│  │   Aurora PostgreSQL    │ ◄─── Multi-AZ Cluster                │
│  │  ┌──────────────────┐  │       - Writer Instance              │
│  │  │ Writer Instance  │  │       - Reader Instance              │
│  │  │   (db.r6g.large) │  │       - Encrypted at rest            │
│  │  └────────┬─────────┘  │       - Auto backups (7 days)        │
│  │  ┌────────▼─────────┐  │                                      │
│  │  │ Reader Instance  │  │                                      │
│  │  │   (db.r6g.large) │  │                                      │
│  │  └──────────────────┘  │                                      │
│  └────────────────────────┘                                      │
│                                                                    │
│  ┌──────────────────┐  ┌───────────────┐  ┌──────────────┐     │
│  │ Secrets Manager  │  │   CloudWatch  │  │     ECR      │     │
│  │  - DB Creds      │  │   - Logs      │  │  - Backend   │     │
│  │  - JWT Secret    │  │   - Metrics   │  │    Image     │     │
│  └──────────────────┘  └───────────────┘  └──────────────┘     │
└────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Archivos Creados

### Nuevos Módulos Terraform:

```
terraform/
├── main.tf                     (ORIGINAL - mantener como backup)
├── main-updated.tf             (NUEVO - usar este)
├── services/
│   ├── waf/
│   │   └── deploy.tf          (YA EXISTÍA)
│   ├── aurora/
│   │   └── main.tf            (NUEVO - Aurora PostgreSQL)
│   └── ecs/
│       └── main.tf            (NUEVO - ECS Fargate + ALB)
└── INSTRUCCIONES_DESPLIEGUE.md (NUEVO - este archivo)
```

### Cambios Principales:

1. **`main-updated.tf`**:
   - Multi-AZ subnets (3 privadas en us-east-1a/b/c)
   - 2 NAT Gateways para alta disponibilidad
   - Integración con módulos Aurora y ECS
   - ECR repository para backend

2. **`services/aurora/main.tf`**:
   - Aurora PostgreSQL cluster 15.4
   - Writer + Reader instances (db.r6g.large)
   - Encriptación con KMS
   - Secrets Manager para credenciales
   - CloudWatch alarms
   - Backups automáticos 7 días

3. **`services/ecs/main.tf`**:
   - ECS Cluster con Container Insights
   - Task Definition con Spring Boot
   - Application Load Balancer
   - Auto Scaling (CPU y Memory)
   - Security Groups configurados
   - CloudWatch Logs

---

## ✅ Pre-requisitos

### 1. Herramientas Necesarias:

```bash
# Verificar versiones
terraform --version  # >= 1.5.0
aws --version        # >= 2.x
docker --version     # >= 20.x

# Configurar AWS CLI
aws configure
# AWS Access Key ID: [tu-access-key]
# AWS Secret Access Key: [tu-secret-key]
# Default region: us-east-1
# Default output format: json
```

### 2. Permisos IAM Necesarios:

Tu usuario AWS necesita permisos para:
- VPC (crear subnets, route tables, NAT gateways)
- RDS (crear Aurora clusters)
- ECS (crear clusters, task definitions, services)
- EC2 (security groups, load balancers)
- ECR (crear repositories)
- Secrets Manager (crear/leer secrets)
- CloudWatch (logs, alarms, metrics)
- IAM (crear roles para ECS)
- KMS (crear keys para encriptación)

**Política recomendada**: `PowerUserAccess` o crear una custom policy.

### 3. Costos Estimados:

| Recurso | Cantidad | Costo Mensual (aprox) |
|---------|----------|----------------------|
| Aurora r6g.large | 2 instances | ~$400 |
| ECS Fargate | 3 tasks (1 vCPU, 2GB) | ~$90 |
| ALB | 1 | ~$20 |
| NAT Gateway | 2 | ~$65 |
| **TOTAL** | | **~$575/mes** |

---

## 🚀 Pasos de Despliegue

### Paso 1: Preparar Terraform

```bash
cd /Users/damian/Documents/terraform

# IMPORTANTE: Backup del main.tf original
cp main.tf main-original-backup.tf

# Reemplazar main.tf con la versión actualizada
cp main-updated.tf main.tf

# Inicializar Terraform (descargar providers)
terraform init
```

### Paso 2: Revisar Plan de Terraform

```bash
# Ver qué recursos se van a crear (NO crea nada aún)
terraform plan

# Deberías ver:
# - 1 VPC
# - 5 Subnets (2 públicas, 3 privadas)
# - 2 NAT Gateways
# - 2 EIPs
# - Route tables y asociaciones
# - Security groups
# - Aurora cluster + 2 instances
# - ECS cluster + service + task definition
# - ALB + target group
# - Secrets Manager secrets (3)
# - CloudWatch log groups
# - IAM roles (2)
# - ECR repository
# - KMS key
# - CloudWatch alarms
# Total: ~45-50 recursos
```

### Paso 3: Aplicar Terraform

```bash
# Crear todos los recursos en AWS
terraform apply

# Terraform te preguntará: "Do you want to perform these actions?"
# Escribe: yes

# Esto tomará ~15-20 minutos
# - Aurora cluster tarda ~10 min en crearse
# - NAT Gateways ~5 min
# - ECS service ~2 min
```

### Paso 4: Guardar Outputs Importantes

```bash
# Después de que termine, guarda estos valores:
terraform output

# Outputs importantes:
# - alb_dns_name: DNS del load balancer (http://educloud-alb-XXXXXXXX.us-east-1.elb.amazonaws.com)
# - aurora_endpoint: Endpoint de Aurora writer
# - ecr_repository_url: URL del ECR para push de imagen
# - ecs_cluster_name: Nombre del cluster ECS
# - app_password: Password de la app (SENSIBLE)

# Para ver el password (está oculto por seguridad):
terraform output -raw app_password
```

---

## 🏗️ Configuración Post-Despliegue

### Paso 1: Crear Usuario de Aplicación en Aurora

**Necesitas conectarte a Aurora y crear el usuario `educloud_app`:**

```bash
# 1. Obtener credenciales master desde Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id educloud/database/master-credentials \
  --query SecretString --output text | jq .

# 2. Conectar a Aurora usando psql (desde una EC2 o con VPN)
psql -h <AURORA_ENDPOINT> -U masteruser -d educloud

# 3. Ejecutar este SQL:
CREATE USER educloud_app WITH PASSWORD '<APP_PASSWORD>';
GRANT CONNECT ON DATABASE educloud TO educloud_app;
GRANT USAGE ON SCHEMA public TO educloud_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO educloud_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO educloud_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO educloud_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO educloud_app;

# 4. Verificar
\du  # Ver usuarios
\q   # Salir
```

**NOTA**: El `<APP_PASSWORD>` está en `terraform output -raw app_password`

### Paso 2: Build y Push Imagen Docker a ECR

```bash
# 1. Autenticar con ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# 2. Build imagen del backend
cd /Users/damian/educloud
docker build -t educloud-backend:latest .

# 3. Tag para ECR
ECR_URL=$(terraform output -raw ecr_repository_url)
docker tag educloud-backend:latest ${ECR_URL}:latest

# 4. Push a ECR
docker push ${ECR_URL}:latest

# 5. Verificar imagen en ECR
aws ecr describe-images --repository-name educloud-backend
```

### Paso 3: Forzar Nuevo Deployment en ECS

```bash
# Una vez que la imagen esté en ECR, forzar nuevo deployment
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)

aws ecs update-service \
  --cluster ${CLUSTER_NAME} \
  --service educloud-backend \
  --force-new-deployment

# Monitorear el deployment
watch -n 5 "aws ecs describe-services \
  --cluster ${CLUSTER_NAME} \
  --services educloud-backend \
  --query 'services[0].deployments' --output table"
```

### Paso 4: Verificar Health Check

```bash
# Obtener DNS del ALB
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test health check
curl http://${ALB_DNS}/api/health

# Deberías ver:
# {
#   "status": "UP",
#   "timestamp": "2025-10-29T...",
#   "details": {
#     "database": "UP",
#     "uptime": "...",
#     "version": "1.0.0"
#   }
# }
```

### Paso 5: Test Completo de API

```bash
# 1. Registrar un usuario
curl -X POST http://${ALB_DNS}/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "nombre": "Test",
    "apellido1": "User",
    "apellido2": "Demo",
    "email": "test@educloud.com",
    "password": "Password123",
    "userType": "TEACHER"
  }'

# 2. Login
curl -X POST http://${ALB_DNS}/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@educloud.com",
    "password": "Password123"
  }'

# 3. Guarda el token de la respuesta y úsalo para requests autenticados
TOKEN="<TOKEN_DE_RESPUESTA>"

curl -H "Authorization: Bearer ${TOKEN}" \
  http://${ALB_DNS}/api/tareas
```

---

## 🔧 Comandos Útiles

### Terraform:

```bash
# Ver estado actual
terraform show

# Listar recursos creados
terraform state list

# Ver output específico
terraform output alb_dns_name

# Destruir TODO (CUIDADO!)
terraform destroy

# Aplicar cambios específicos
terraform apply -target=module.ecs
```

### AWS CLI - ECS:

```bash
# Ver logs del backend
aws logs tail /ecs/educloud-backend --follow

# Ver tasks running
aws ecs list-tasks --cluster educloud-cluster

# Describe task specific
aws ecs describe-tasks \
  --cluster educloud-cluster \
  --tasks <TASK_ARN>

# Ejecutar comando en task (debugging)
aws ecs execute-command \
  --cluster educloud-cluster \
  --task <TASK_ID> \
  --container educloud-backend \
  --interactive \
  --command "/bin/sh"
```

### AWS CLI - Aurora:

```bash
# Ver estado del cluster
aws rds describe-db-clusters \
  --db-cluster-identifier educloud-cluster

# Ver instancias
aws rds describe-db-cluster-endpoints \
  --db-cluster-identifier educloud-cluster

# Ver métricas de CPU
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBClusterIdentifier,Value=educloud-cluster \
  --start-time 2025-10-29T00:00:00Z \
  --end-time 2025-10-29T23:59:59Z \
  --period 3600 \
  --statistics Average
```

### AWS CLI - Secrets Manager:

```bash
# Ver secrets
aws secretsmanager list-secrets

# Obtener DB credentials
aws secretsmanager get-secret-value \
  --secret-id educloud/database/app-credentials \
  --query SecretString --output text | jq .

# Rotar secret (opcional)
aws secretsmanager rotate-secret \
  --secret-id educloud/jwt/secret
```

---

## 🐛 Troubleshooting

### Problema 1: ECS Tasks no arrancan

**Síntomas**: Tasks en estado STOPPED, error "CannotPullContainerError"

**Solución**:
```bash
# Verificar que la imagen existe en ECR
aws ecr describe-images --repository-name educloud-backend

# Verificar permisos IAM del execution role
aws iam get-role --role-name educloud-ecs-execution-role

# Ver logs de error
aws ecs describe-tasks \
  --cluster educloud-cluster \
  --tasks <TASK_ARN> \
  --query 'tasks[0].containers[0].reason'
```

### Problema 2: Health Check falla

**Síntomas**: Tasks se crean pero ALB las marca como unhealthy

**Solución**:
```bash
# Ver logs del contenedor
aws logs tail /ecs/educloud-backend --follow

# Verificar conectividad a Aurora
aws rds describe-db-clusters \
  --db-cluster-identifier educloud-cluster \
  --query 'DBClusters[0].Status'

# Test manual del health endpoint desde dentro del task
aws ecs execute-command \
  --cluster educloud-cluster \
  --task <TASK_ID> \
  --container educloud-backend \
  --interactive \
  --command "curl http://localhost:8080/api/health"
```

### Problema 3: Aurora no acepta conexiones

**Síntomas**: Error "could not connect to server"

**Solución**:
```bash
# Verificar security groups
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=educloud-aurora-sg"

# Ver reglas ingress (debe permitir puerto 5432 desde ECS SG)
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=<AURORA_SG_ID>"

# Verificar que ECS tasks están en subnet privada correcta
aws ecs describe-tasks \
  --cluster educloud-cluster \
  --tasks <TASK_ARN> \
  --query 'tasks[0].attachments[0].details'
```

### Problema 4: Secrets Manager no se lee

**Síntomas**: Error "AccessDeniedException" al leer secrets

**Solución**:
```bash
# Verificar permisos del execution role
aws iam get-role-policy \
  --role-name educloud-ecs-execution-role \
  --policy-name educloud-ecs-execution-policy

# Test manual de lectura de secret
aws secretsmanager get-secret-value \
  --secret-id educloud/database/app-credentials
```

### Problema 5: CORS errors en frontend

**Síntomas**: Browser muestra "blocked by CORS policy"

**Verificar**:
1. Variable `CORS_ALLOWED_ORIGINS` en task definition
2. Incluye el dominio del frontend (https://tudominio.com)
3. Re-deploy ECS service después de cambiar

**Cambiar CORS origins**:
```bash
# Editar main.tf, cambiar:
# cors_allowed_origins = "https://educloud.com,https://www.educloud.com,https://TU_FRONTEND_URL"

terraform apply -target=module.ecs
```

---

## 📊 Monitoreo

### CloudWatch Dashboards:

Crea un dashboard custom con estas métricas:

**ECS Metrics**:
- CPUUtilization
- MemoryUtilization
- RunningTasksCount

**Aurora Metrics**:
- CPUUtilization
- DatabaseConnections
- FreeableMemory
- ReadLatency / WriteLatency

**ALB Metrics**:
- RequestCount
- TargetResponseTime
- HTTPCode_Target_2XX_Count
- HTTPCode_Target_5XX_Count

### Alarmas Configuradas:

Ya creadas por Terraform:
- `educloud-aurora-high-cpu` (>80% CPU)
- `educloud-aurora-high-connections` (>80 connections)
- `educloud-ecs-high-cpu` (>80% CPU)
- `educloud-ecs-high-memory` (>80% Memory)

---

## 🔒 Seguridad - Checklist Final

Antes de ir a producción:

- [ ] Cambiar `cors_allowed_origins` a dominios específicos
- [ ] Habilitar HTTPS listener en ALB (descomentar en ecs/main.tf)
- [ ] Crear certificado ACM para tu dominio
- [ ] Configurar Route 53 apuntando a ALB
- [ ] Habilitar deletion protection en Aurora
- [ ] Configurar SNS topic para alarmas
- [ ] Limitar SSH (puerto 22) a IP específica en security groups
- [ ] Rotar secretos de Secrets Manager periódicamente
- [ ] Configurar AWS GuardDuty para detección de amenazas
- [ ] Habilitar AWS Config para compliance
- [ ] Configurar backups adicionales con AWS Backup
- [ ] Crear rol de read-only para acceso de emergencia

---

## 📝 Notas Importantes

1. **Aurora tarda ~10 min en crearse** - sé paciente con `terraform apply`

2. **NAT Gateways cuestan ~$0.045/hora cada uno** - son necesarios para que ECS acceda a internet (pull de ECR, etc.)

3. **Secrets Manager cobra por secret** - actualmente tienes 3 secrets (~$1.20/mes)

4. **Auto Scaling está configurado** - ECS escalará de 3 a 10 tasks según CPU/Memory

5. **Backups de Aurora son automáticos** - 7 días de retención

6. **No hay DNS configurado aún** - acceso por DNS del ALB (largo y feo), necesitas Route 53

7. **SSL/TLS no está habilitado** - necesitas ACM certificate primero

8. **El password de Aurora está en Terraform state** - guarda el state en S3 con encriptación

---

## 🆘 Soporte

Si algo falla:

1. **Ver logs**: `aws logs tail /ecs/educloud-backend --follow`
2. **Ver eventos ECS**: `aws ecs describe-services --cluster educloud-cluster --services educloud-backend`
3. **Contactar al equipo de desarrollo backend** con los logs

---

**Creado por**: Equipo EduCloud
**Fecha**: 29 Octubre 2025
**Versión Terraform**: 1.5+
**AWS Provider**: 6.0+