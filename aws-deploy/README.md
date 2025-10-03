# AWS Deployment Scripts

Scripts automatizados para desplegar NGINX RTMP/HLS Server en AWS con CloudFront.

## 🚀 Quick Start

### Configuración desde cero (nueva instalación)

```bash
# 1. Configurar credenciales AWS
aws configure

# 2. Editar configuración (opcional)
nano aws-config.env

# 3. Ejecutar setup completo
./setup-aws.sh
```

Esto creará:
- ✅ EC2 instance con NGINX RTMP/HLS
- ✅ Security Group con puertos 22, 1935, 8080
- ✅ CloudFront distribution con HTTPS
- ✅ Configuración optimizada para streaming

### Actualizar CloudFront existente

Si ya tienes CloudFront creado:

```bash
# Listar tus distribuciones
aws cloudfront list-distributions --query 'DistributionList.Items[*].[Id,DomainName]' --output table

# Actualizar configuración
./update-existing-cloudfront.sh <DISTRIBUTION_ID>
```

## 📁 Archivos

### Scripts principales

- **`setup-aws.sh`** - Script maestro que ejecuta todo
- **`aws-ec2-setup.sh`** - Crea y configura EC2 instance
- **`aws-cloudfront-setup.sh`** - Crea CloudFront distribution
- **`update-existing-cloudfront.sh`** - Actualiza CloudFront existente
- **`cleanup-aws.sh`** - Elimina todos los recursos creados

### Configuración

- **`aws-config.env`** - Variables de configuración

### Archivos generados (no versionar)

- `ec2-info.txt` - Información de la instancia EC2
- `cloudfront-info.txt` - Información de CloudFront
- `nginx-rtmp-key.pem` - Clave SSH (⚠️ mantener segura)
- `ec2-userdata.sh` - Script de instalación en EC2
- `cloudfront-distribution-config.json` - Config de CloudFront

## ⚙️ Configuración

Edita `aws-config.env` para personalizar:

```bash
# Región
AWS_REGION="us-east-1"

# Tipo de instancia EC2
EC2_INSTANCE_TYPE="t3.medium"  # t3.small, t3.large, etc.

# Nombres de streams RTMP
RTMP_STREAM_NAMES="live,testing"

# CloudFront Price Class
CLOUDFRONT_PRICE_CLASS="PriceClass_100"  # USA, Canada, Europe
```

## 🎥 Uso después del deployment

### URLs generadas

Después del setup, obtendrás:

**EC2 directo (HTTP):**
```
HLS:  http://ec2-xxx.compute-1.amazonaws.com:8080/hls/mystream.m3u8
Stat: http://ec2-xxx.compute-1.amazonaws.com:8080/stat
RTMP: rtmp://ec2-xxx.compute-1.amazonaws.com:1935/live
```

**CloudFront (HTTPS):**
```
HLS:  https://dxxxxx.cloudfront.net/hls/mystream.m3u8
Stat: https://dxxxxx.cloudfront.net/stat
```

### Configurar OBS Studio

1. **Streaming Service:** Custom
2. **Server:** `rtmp://ec2-xxx.compute-1.amazonaws.com:1935/live`
3. **Stream Key:** `mystream`

### Usar en vodlix.cloud

Usa la URL de CloudFront (HTTPS):
```
https://dxxxxx.cloudfront.net/hls/mystream.m3u8
```

## 🔧 Administración

### SSH a la instancia EC2

```bash
ssh -i nginx-rtmp-key.pem ec2-user@<PUBLIC_IP>
```

### Ver logs del contenedor Docker

```bash
ssh -i nginx-rtmp-key.pem ec2-user@<PUBLIC_IP>
sudo docker logs -f nginx-rtmp
```

### Reiniciar el servicio

```bash
ssh -i nginx-rtmp-key.pem ec2-user@<PUBLIC_IP>
sudo systemctl restart nginx-rtmp
```

### Verificar status de CloudFront

```bash
aws cloudfront get-distribution \
  --id <DISTRIBUTION_ID> \
  --query 'Distribution.Status'
```

## 🗑️ Eliminar recursos

⚠️ **Esto eliminará TODOS los recursos creados**

```bash
./cleanup-aws.sh
```

Elimina:
- EC2 instance
- Security Group
- Key Pair
- CloudFront distribution (tarda ~15 min)

## 📊 Costos estimados AWS

Estimación mensual (us-east-1):

| Recurso | Costo aproximado |
|---------|------------------|
| EC2 t3.medium (24/7) | ~$30/mes |
| CloudFront (100 GB) | ~$8.50/mes |
| Data Transfer OUT | Variable |
| **Total** | **~$40-60/mes** |

💡 **Tip:** Para reducir costos, usa instancia más pequeña (t3.small) o detén la instancia cuando no la uses.

## 🐛 Troubleshooting

### No se reproduce el stream en vodlix.cloud

**Causa:** Mixed Content (HTTP en página HTTPS)

**Solución:** Usa la URL de CloudFront (HTTPS):
```
https://dxxxxx.cloudfront.net/hls/mystream.m3u8
```

### CloudFront retorna 404

**Causas posibles:**
1. Distribution aún no está deployed (espera 5-10 min)
2. Cache incorrecto

**Solución:**
```bash
# Crear invalidación
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/hls/*"
```

### OBS no puede conectarse

**Causas posibles:**
1. Security Group no tiene puerto 1935 abierto
2. Servidor NGINX no está corriendo

**Solución:**
```bash
# Verificar security group
aws ec2 describe-security-groups \
  --group-ids <SG_ID> \
  --query 'SecurityGroups[0].IpPermissions'

# Verificar que el contenedor está corriendo
ssh -i nginx-rtmp-key.pem ec2-user@<PUBLIC_IP>
sudo docker ps
sudo systemctl status nginx-rtmp
```

### Error de credenciales AWS

```bash
aws configure
```

Necesitas:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: `us-east-1`

## 📚 Recursos adicionales

- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)
- [CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [NGINX RTMP Module](https://github.com/arut/nginx-rtmp-module)
- [HLS Streaming Guide](https://developer.apple.com/documentation/http_live_streaming)

## 🔒 Seguridad

⚠️ **Recomendaciones:**

1. **Protege tu archivo .pem:**
   ```bash
   chmod 400 nginx-rtmp-key.pem
   ```

2. **No versiones archivos sensibles:**
   - `*.pem`
   - `*-info.txt`
   - `ec2-userdata.sh`

3. **Restringe acceso SSH:**
   Edita el Security Group para permitir SSH solo desde tu IP:
   ```bash
   aws ec2 authorize-security-group-ingress \
     --group-id <SG_ID> \
     --protocol tcp \
     --port 22 \
     --cidr <TU_IP>/32
   ```

4. **Autenticación RTMP (opcional):**
   Modifica `run.sh` para agregar autenticación en el endpoint `/on_publish`

## 📝 Licencia

MIT License - Ver archivo LICENSE en el repositorio principal
