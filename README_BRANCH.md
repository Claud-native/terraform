# Branch: feature/educloud-backend-aurora-ecs

## 🎯 Propósito

Esta rama contiene la infraestructura completa para **EduCloud Backend** con:
- ✅ Aurora PostgreSQL Multi-AZ
- ✅ ECS Fargate con Auto-Scaling
- ✅ Application Load Balancer
- ✅ Secrets Manager para credenciales
- ✅ CloudWatch monitoring y alarms
- ✅ ECR repository para imágenes Docker

## 📊 Diferencias con `main`

| Aspecto | main (original) | Esta rama |
|---------|----------------|-----------|
| **Subnets** | 1 pública, 1 privada (us-east-1a) | 2 públicas, 3 privadas (multi-AZ) |
| **NAT Gateway** | 1 NAT Gateway | 2 NAT Gateways (HA) |
| **Base de Datos** | No configurada | Aurora PostgreSQL cluster |
| **Backend** | No configurado | ECS Fargate + ALB |
| **Secrets** | No configurado | Secrets Manager integrado |
| **Monitoring** | Básico (WAF logs) | Completo (CloudWatch + alarmas) |
| **Módulos** | 1 módulo (WAF) | 3 módulos (WAF, Aurora, ECS) |

## 🗂️ Estructura de Archivos

```
terraform/
├── main.tf                          ← Actualizado con multi-AZ y módulos
├── readme.md                        ← Original (sin cambios)
├── README_BRANCH.md                 ← Este archivo (NUEVO)
├── INSTRUCCIONES_DESPLIEGUE.md      ← Guía completa de deployment (NUEVO)
├── services/
│   ├── waf/
│   │   └── deploy.tf                ← Original (sin cambios)
│   ├── aurora/                      ← NUEVO
│   │   └── main.tf                  ← Aurora cluster + secrets
│   └── ecs/                         ← NUEVO
│       └── main.tf                  ← ECS Fargate + ALB + auto-scaling
```

## 🚀 Cómo Usar Esta Rama

### 1. Cambiar a Esta Rama

```bash
cd /Users/damian/Documents/terraform
git checkout feature/educloud-backend-aurora-ecs
```

### 2. Inicializar Terraform

```bash
terraform init
```

### 3. Revisar Plan

```bash
terraform plan
```

### 4. Aplicar (Crear Infraestructura)

```bash
terraform apply
```

**NOTA**: Lee `INSTRUCCIONES_DESPLIEGUE.md` para pasos detallados post-deployment.

## 📋 Recursos Creados

Esta rama crea **~50 recursos** en total:

### Networking:
- 1 VPC (10.0.0.0/16)
- 5 Subnets (2 públicas, 3 privadas)
- 1 Internet Gateway
- 2 NAT Gateways
- 2 Elastic IPs
- 5 Route Tables
- 7 Route Table Associations
- 3 Security Groups (público, privado, aurora, alb, ecs-tasks)

### Database:
- 1 Aurora PostgreSQL Cluster
- 2 Aurora Instances (writer + reader, db.r6g.large)
- 1 DB Subnet Group
- 1 KMS Key para encriptación
- 2 CloudWatch Alarms (CPU, connections)

### Backend (ECS):
- 1 ECS Cluster
- 1 ECS Task Definition
- 1 ECS Service (3 tasks, auto-scaling 3-10)
- 1 Application Load Balancer
- 1 Target Group
- 1 ALB Listener (HTTP, con opción para HTTPS)
- 2 Auto Scaling Policies (CPU, Memory)
- 2 CloudWatch Alarms (CPU, Memory)

### Secrets & Security:
- 3 Secrets Manager Secrets (DB master, DB app, JWT)
- 3 Secret Versions
- 2 IAM Roles (ECS execution, ECS task)
- 2 IAM Policies
- 1 IAM Role para RDS Enhanced Monitoring

### Monitoring:
- 2 CloudWatch Log Groups (ECS logs, WAF logs)
- 6 CloudWatch Alarms (Aurora x2, ECS x2, WAF incluido)

### Container Registry:
- 1 ECR Repository (educloud-backend)

### Existing (No Modified):
- 1 WAF Web ACL (del main original)
- WAF Rules y logging

## 💰 Costos Estimados

| Categoría | Mensual |
|-----------|---------|
| Aurora (2x r6g.large) | ~$400 |
| ECS Fargate (3 tasks) | ~$90 |
| ALB | ~$20 |
| NAT Gateways (2x) | ~$65 |
| Secrets Manager | ~$1 |
| CloudWatch Logs | ~$5 |
| ECR | ~$1 |
| Data Transfer | ~$10-20 |
| **TOTAL** | **~$590-600/mes** |

## 🔄 Merge a Main

Cuando estés listo para hacer merge a `main`:

```bash
# 1. Asegúrate de que todo funciona
terraform plan  # debe estar "clean"

# 2. Push de esta rama (opcional pero recomendado)
git push -u origin feature/educloud-backend-aurora-ecs

# 3. Cambiar a main
git checkout main

# 4. Merge (recomendado hacer Pull Request en GitHub primero)
git merge feature/educloud-backend-aurora-ecs

# 5. Push a main
git push origin main
```

**IMPORTANTE**: Coordina con tu compañero antes del merge para no pisar su trabajo.

## ⚠️ Advertencias

1. **No ejecutar `terraform destroy` sin backup** - destruirá toda la infraestructura incluyendo la base de datos

2. **Aurora tarda ~10 min en crearse** - sé paciente con `terraform apply`

3. **NAT Gateways cuestan dinero** - están siempre encendidos

4. **El state de Terraform contiene secrets** - no lo subas a git público

5. **Necesitas configurar el usuario de app manualmente** - ver INSTRUCCIONES_DESPLIEGUE.md paso "Configuración Post-Despliegue"

## 📚 Documentación

- **Deployment completo**: `INSTRUCCIONES_DESPLIEGUE.md`
- **Variables backend**: `/Users/damian/educloud/VARIABLES_ENTORNO.md`
- **AWS Deployment**: `/Users/damian/educloud/AWS_DEPLOYMENT_GUIDE.md`
- **Dockerfile**: `/Users/damian/educloud/Dockerfile`

## ✅ Checklist Antes de Merge

- [ ] `terraform plan` sin errores
- [ ] Backend desplegado exitosamente en ECS
- [ ] Health check pasando (`/api/health` retorna 200)
- [ ] Aurora accesible desde ECS tasks
- [ ] Secrets Manager configurado correctamente
- [ ] ALB respondiendo en puerto 80
- [ ] Auto-scaling testeado
- [ ] CloudWatch logs funcionando
- [ ] Documentación completa
- [ ] Tu compañero revisó los cambios

## 👥 Contacto

Para dudas sobre esta infraestructura:
- **Backend**: Equipo de desarrollo backend
- **Terraform**: Tu compañero arquitecto
- **AWS**: Equipo DevOps

---

**Branch creada**: 29 Octubre 2025
**Última actualización**: 29 Octubre 2025
**Terraform version**: >= 1.5.0
**AWS Provider version**: ~> 6.0
