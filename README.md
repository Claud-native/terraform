# Infraestructura VPN + Nextcloud en AWS

## Arquitectura

```
Internet
   │
   ├──> WAF ──> Load Balancer ──> Web (subred pública)
   │
   └──> Wireguard VPN (EC2 en subred pública)
          │
          └──> [Conexión VPN] ──> Nextcloud (EC2 en subred privada)
                                      │
                                      └──> S3 (vía VPC Endpoint)
```

## Componentes Desplegados

1. **Wireguard VPN Server** - EC2 en subred pública (10.0.1.0/24)
   - Puerto: UDP 51820
   - 5 peers configurados
   - Acceso público desde Internet

2. **Nextcloud Server** - EC2 en subred privada (10.0.2.0/24)
   - Puerto: HTTP 80
   - Solo accesible desde VPN
   - Almacenamiento: S3

3. **S3 Bucket** - Almacenamiento para Nextcloud
   - Acceso privado vía VPC Endpoint
   - Sin acceso público

## Despliegue

```bash
cd terraform
terraform init
terraform apply
```

## Configuración Post-Despliegue

### 1. Obtener IP del servidor Wireguard

```bash
terraform output -json | grep wireguard_public_ip
```

O ejecutar:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=wireguard-vpn-server" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

### 2. Conectarse al servidor Wireguard

```bash
# Descargar la clave PEM desde AWS Academy (botón "Download PEM")
chmod 400 vockey.pem

# Conectar vía SSH
ssh -i vockey.pem ubuntu@<WIREGUARD_PUBLIC_IP>
```

### 3. Obtener configuración de cliente VPN

Una vez conectado al servidor Wireguard:

```bash
# Opción 1: Ver QR code en terminal (escanear con app móvil)
sudo docker exec wireguard /app/show-peer 1

# Opción 2: Ver configuración en texto
sudo cat /opt/wireguard/config/peer1/peer1.conf

# Opción 3: Ver todos los peers disponibles
sudo ls -la /opt/wireguard/config/peer*/
```

**Peers disponibles:** peer1, peer2, peer3, peer4, peer5

### 4. Instalar y configurar cliente Wireguard

#### En Linux/Mac:
```bash
# Copiar configuración
scp -i vockey.pem ubuntu@<WIREGUARD_IP>:/opt/wireguard/config/peer1/peer1.conf ./

# Instalar Wireguard
sudo apt install wireguard  # Ubuntu/Debian
brew install wireguard-tools  # Mac

# Conectar
sudo wg-quick up ./peer1.conf
```

#### En Windows:
1. Descargar [Wireguard para Windows](https://www.wireguard.com/install/)
2. Abrir la aplicación
3. Click "Add Tunnel" → "Import from file"
4. Seleccionar el archivo `peer1.conf`
5. Click "Activate"

#### En Android/iOS:
1. Descargar app Wireguard desde Play Store/App Store
2. Escanear el QR code mostrado en el terminal
3. Activar la conexión

### 5. Obtener IP del servidor Nextcloud

**Opción 1 - Usando Terraform:**
```bash
terraform output -json | grep nextcloud_private_ip
```

**Opción 2 - Usando AWS CLI:**
```bash
# Obtener Instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=nextcloud-server" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

# Obtener IP privada
aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text
```

### 6. Acceder a Nextcloud

Una vez conectado a la VPN:

```bash
# Abrir en el navegador
http://<NEXTCLOUD_PRIVATE_IP>
```

**Credenciales por defecto:**
- Usuario: `admin`
- Contraseña: `AdminPassword123!`

### 7. Verificar almacenamiento en S3

Después de subir archivos en Nextcloud:

```bash
# Listar bucket S3
aws s3 ls s3://nextcloud-storage-<ACCOUNT_ID>/ --recursive

# Ver nombre del bucket
terraform output s3_bucket_name
```

## Comandos Útiles

### Ver logs de Wireguard
```bash
ssh -i vockey.pem ubuntu@<WIREGUARD_IP>
sudo docker logs wireguard
```

### Ver logs de Nextcloud
```bash
# Desde Wireguard, conectarse a Nextcloud
ssh -i vockey.pem ubuntu@<NEXTCLOUD_PRIVATE_IP>
sudo docker logs nextcloud
```

### Reiniciar servicios
```bash
# Wireguard
ssh -i vockey.pem ubuntu@<WIREGUARD_IP>
cd /opt/wireguard
sudo docker-compose restart

# Nextcloud
ssh -i vockey.pem ubuntu@<NEXTCLOUD_PRIVATE_IP>
cd /opt/nextcloud
sudo docker-compose restart
```

### Verificar configuración S3 en Nextcloud
```bash
ssh -i vockey.pem ubuntu@<NEXTCLOUD_PRIVATE_IP>
sudo docker exec nextcloud cat /var/www/html/config/s3.config.php
```

## Troubleshooting

### No puedo conectarme a Wireguard
1. Verificar que el puerto UDP 51820 esté abierto en el firewall
2. Verificar Security Group permite UDP 51820 desde 0.0.0.0/0
3. Revisar logs: `sudo docker logs wireguard`

### No puedo acceder a Nextcloud desde la VPN
1. Verificar que la VPN está activa: `sudo wg show`
2. Hacer ping: `ping <NEXTCLOUD_PRIVATE_IP>`
3. Verificar Security Group de Nextcloud permite tráfico desde 10.0.0.0/16
4. Revisar logs: `sudo docker logs nextcloud`

### Los archivos no se guardan en S3
1. Verificar rol IAM de la instancia EC2 tiene permisos de S3
2. Verificar configuración: `sudo docker exec nextcloud cat /var/www/html/config/s3.config.php`
3. Revisar VPC Endpoint de S3: `aws ec2 describe-vpc-endpoints`
4. Revisar bucket policy permite acceso desde VPC Endpoint

### Nextcloud muestra error de base de datos
1. Esperar 2-3 minutos después del despliegue
2. Reiniciar el contenedor: `sudo docker restart nextcloud`
3. Verificar inicialización completa: `sudo docker logs nextcloud | grep -i "ready"`

## Limpieza

Para eliminar toda la infraestructura:

```bash
terraform destroy
```

**Nota:** El bucket S3 puede fallar al destruirse si contiene objetos. En ese caso:

```bash
# Vaciar bucket primero
aws s3 rm s3://nextcloud-storage-<ACCOUNT_ID>/ --recursive

# Luego destruir
terraform destroy
```

## Seguridad

### Recomendaciones de Producción

1. **Cambiar credenciales por defecto de Nextcloud**
2. **Limitar acceso SSH:** Modificar Security Groups para permitir SSH solo desde IPs específicas
3. **Habilitar HTTPS:** Configurar certificado SSL/TLS
4. **Rotar claves VPN:** Regenerar configuraciones de peers periódicamente
5. **Monitoreo:** Configurar CloudWatch Alarms para EC2 y tráfico de red
6. **Backups:** Configurar snapshots automáticos de volúmenes EBS
7. **MFA:** Habilitar autenticación de dos factores en Nextcloud

### Acceso a recursos

- **Wireguard:** Solo accesible desde Internet en puerto UDP 51820
- **Nextcloud:** Solo accesible desde VPC (10.0.0.0/16) - requiere VPN
- **S3:** Solo accesible desde VPC vía VPC Endpoint

## Costos Estimados (AWS Academy - USD/mes)

- EC2 t3.small (Wireguard): ~$15/mes
- EC2 t3.medium (Nextcloud): ~$30/mes
- NAT Gateway: ~$32/mes
- S3 Storage: ~$0.023/GB
- Data Transfer: Variable

**Total aproximado:** ~$80-100/mes (sin contar tráfico)

## Soporte

Para issues o mejoras, contactar al equipo de infraestructura.
