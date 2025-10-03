#!/bin/bash

# ============================================
# AWS EC2 Setup Script para NGINX RTMP/HLS
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/aws-config.env"

echo "=========================================="
echo "Configurando EC2 para NGINX RTMP/HLS"
echo "=========================================="
echo ""

# Verificar AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ Error: AWS CLI no está instalado"
    echo "Instala con: brew install awscli"
    exit 1
fi

# Verificar credenciales AWS
echo "1. Verificando credenciales AWS..."
aws sts get-caller-identity > /dev/null 2>&1 || {
    echo "❌ Error: No hay credenciales AWS configuradas"
    echo "Ejecuta: aws configure"
    exit 1
}
echo "✓ Credenciales AWS verificadas"
echo ""

# Crear Security Group
echo "2. Creando Security Group..."
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${SECURITY_GROUP_NAME}" \
    --query 'SecurityGroups[0].GroupId' \
    --output text \
    --region ${AWS_REGION} 2>/dev/null)

if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
    echo "   Creando nuevo Security Group: ${SECURITY_GROUP_NAME}"
    SG_ID=$(aws ec2 create-security-group \
        --group-name ${SECURITY_GROUP_NAME} \
        --description "${SECURITY_GROUP_DESC}" \
        --region ${AWS_REGION} \
        --query 'GroupId' \
        --output text)

    # Esperar a que se cree
    sleep 2

    # Agregar reglas de ingress
    for PORT in ${PORTS_TCP}; do
        echo "   Abriendo puerto TCP ${PORT}..."
        aws ec2 authorize-security-group-ingress \
            --group-id ${SG_ID} \
            --protocol tcp \
            --port ${PORT} \
            --cidr 0.0.0.0/0 \
            --region ${AWS_REGION} > /dev/null 2>&1 || true
    done

    echo "✓ Security Group creado: ${SG_ID}"
else
    echo "✓ Security Group ya existe: ${SG_ID}"
fi
echo ""

# Verificar/Crear Key Pair
echo "3. Verificando SSH Key Pair..."
KEY_EXISTS=$(aws ec2 describe-key-pairs \
    --filters "Name=key-name,Values=${EC2_KEY_NAME}" \
    --query 'KeyPairs[0].KeyName' \
    --output text \
    --region ${AWS_REGION} 2>/dev/null || echo "None")

if [ "$KEY_EXISTS" == "None" ] || [ -z "$KEY_EXISTS" ]; then
    echo "   Creando nuevo Key Pair: ${EC2_KEY_NAME}"
    aws ec2 create-key-pair \
        --key-name ${EC2_KEY_NAME} \
        --region ${AWS_REGION} \
        --query 'KeyMaterial' \
        --output text > "${SCRIPT_DIR}/${EC2_KEY_NAME}.pem"

    chmod 400 "${SCRIPT_DIR}/${EC2_KEY_NAME}.pem"
    echo "✓ Key Pair creado: ${SCRIPT_DIR}/${EC2_KEY_NAME}.pem"
    echo "⚠️  IMPORTANTE: Guarda este archivo .pem de forma segura"
else
    echo "✓ Key Pair ya existe: ${EC2_KEY_NAME}"
    if [ ! -f "${SCRIPT_DIR}/${EC2_KEY_NAME}.pem" ]; then
        echo "⚠️  Advertencia: No se encontró ${EC2_KEY_NAME}.pem localmente"
        echo "   Si lo perdiste, necesitarás crear uno nuevo"
    fi
fi
echo ""

# Obtener AMI más reciente de Amazon Linux 2023
echo "4. Obteniendo AMI más reciente de Amazon Linux 2023..."
AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=al2023-ami-2023.*-x86_64" \
              "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text \
    --region ${AWS_REGION})
echo "✓ AMI ID: ${AMI_ID}"
echo ""

# Crear User Data script para EC2
echo "5. Preparando script de instalación..."
cat > "${SCRIPT_DIR}/ec2-userdata.sh" <<'USERDATA_EOF'
#!/bin/bash
# Script ejecutado automáticamente al iniciar la instancia EC2

set -e

echo "=========================================="
echo "Instalando Docker y NGINX RTMP en EC2"
echo "=========================================="

# Actualizar sistema
dnf update -y

# Instalar Docker
dnf install -y docker
systemctl start docker
systemctl enable docker

# Agregar usuario ec2-user al grupo docker
usermod -aG docker ec2-user

# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Cargar o construir la imagen NGINX RTMP
echo "Cargando imagen Docker..."

# Opción 1: Construir desde GitHub
cd /home/ec2-user
git clone https://github.com/alcarazolabs/nginx-rtmp-hls-server.git || true
cd nginx-rtmp-hls-server

# Construir imagen
docker build -t alcarazolabs/nginx-rtmp-hls:latest .

# Crear servicio systemd para el contenedor
cat > /etc/systemd/system/nginx-rtmp.service <<'EOF'
[Unit]
Description=NGINX RTMP/HLS Streaming Server
After=docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=5s
ExecStartPre=-/usr/bin/docker stop nginx-rtmp
ExecStartPre=-/usr/bin/docker rm nginx-rtmp
ExecStart=/usr/bin/docker run --rm \
  --name nginx-rtmp \
  -p 1935:1935 \
  -p 8080:8080 \
  -e RTMP_STREAM_NAMES=live,testing \
  alcarazolabs/nginx-rtmp-hls:latest
ExecStop=/usr/bin/docker stop nginx-rtmp

[Install]
WantedBy=multi-user.target
EOF

# Iniciar servicio
systemctl daemon-reload
systemctl enable nginx-rtmp
systemctl start nginx-rtmp

echo "✓ Instalación completada"
echo "Servidor NGINX RTMP/HLS corriendo en:"
echo "  - RTMP: rtmp://$(curl -s http://169.254.169.254/latest/meta-data/public-hostname):1935/live/mystream"
echo "  - HLS:  http://$(curl -s http://169.254.169.254/latest/meta-data/public-hostname):8080/hls/mystream.m3u8"
USERDATA_EOF

echo "✓ Script de instalación preparado"
echo ""

# Lanzar instancia EC2
echo "6. Lanzando instancia EC2..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id ${AMI_ID} \
    --instance-type ${EC2_INSTANCE_TYPE} \
    --key-name ${EC2_KEY_NAME} \
    --security-group-ids ${SG_ID} \
    --user-data file://${SCRIPT_DIR}/ec2-userdata.sh \
    --tag-specifications \
        "ResourceType=instance,Tags=[{Key=Name,Value=${EC2_INSTANCE_NAME}},{Key=Project,Value=${TAG_PROJECT}},{Key=Environment,Value=${TAG_ENVIRONMENT}}]" \
    --region ${AWS_REGION} \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "✓ Instancia EC2 creada: ${INSTANCE_ID}"
echo ""

# Esperar a que la instancia esté corriendo
echo "7. Esperando a que la instancia esté corriendo..."
aws ec2 wait instance-running \
    --instance-ids ${INSTANCE_ID} \
    --region ${AWS_REGION}
echo "✓ Instancia corriendo"
echo ""

# Obtener información de la instancia
echo "8. Obteniendo información de la instancia..."
INSTANCE_INFO=$(aws ec2 describe-instances \
    --instance-ids ${INSTANCE_ID} \
    --region ${AWS_REGION} \
    --query 'Reservations[0].Instances[0]')

PUBLIC_IP=$(echo $INSTANCE_INFO | jq -r '.PublicIpAddress')
PUBLIC_DNS=$(echo $INSTANCE_INFO | jq -r '.PublicDnsName')

echo ""
echo "=========================================="
echo "✓ EC2 Instance creada exitosamente"
echo "=========================================="
echo ""
echo "Instance ID: ${INSTANCE_ID}"
echo "Public IP:   ${PUBLIC_IP}"
echo "Public DNS:  ${PUBLIC_DNS}"
echo ""
echo "SSH Key:     ${SCRIPT_DIR}/${EC2_KEY_NAME}.pem"
echo ""
echo "Conectar via SSH:"
echo "  ssh -i ${EC2_KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
echo ""
echo "⏳ La instalación de Docker y NGINX tardará ~5 minutos"
echo "   Monitorea el progreso:"
echo "   ssh -i ${EC2_KEY_NAME}.pem ec2-user@${PUBLIC_IP} 'tail -f /var/log/cloud-init-output.log'"
echo ""
echo "URLs del servicio (disponibles en ~5 min):"
echo "  RTMP: rtmp://${PUBLIC_DNS}:1935/live/mystream"
echo "  HLS:  http://${PUBLIC_DNS}:8080/hls/mystream.m3u8"
echo "  Stat: http://${PUBLIC_DNS}:8080/stat"
echo ""

# Guardar información en archivo
cat > "${SCRIPT_DIR}/ec2-info.txt" <<EOF
INSTANCE_ID=${INSTANCE_ID}
PUBLIC_IP=${PUBLIC_IP}
PUBLIC_DNS=${PUBLIC_DNS}
REGION=${AWS_REGION}
CREATED=$(date)
EOF

echo "Información guardada en: ${SCRIPT_DIR}/ec2-info.txt"
echo ""
