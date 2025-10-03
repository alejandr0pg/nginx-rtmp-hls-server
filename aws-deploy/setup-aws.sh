#!/bin/bash

# ============================================
# Script Maestro: Configuración completa AWS
# NGINX RTMP/HLS Server con CloudFront
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   AWS NGINX RTMP/HLS Server Setup     ║"
echo "║   Configuración completa desde cero   ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Verificar prerequisitos
echo "Verificando prerequisitos..."
echo ""

if ! command -v aws &> /dev/null; then
    echo "❌ Error: AWS CLI no está instalado"
    echo ""
    echo "Instalar en macOS:"
    echo "  brew install awscli"
    echo ""
    echo "Instalar en Linux:"
    echo "  curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\""
    echo "  unzip awscliv2.zip"
    echo "  sudo ./aws/install"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq no está instalado"
    echo ""
    echo "Instalar en macOS:"
    echo "  brew install jq"
    echo ""
    echo "Instalar en Linux:"
    echo "  sudo apt-get install jq  # Debian/Ubuntu"
    echo "  sudo yum install jq      # CentOS/RHEL"
    exit 1
fi

# Verificar credenciales AWS
aws sts get-caller-identity > /dev/null 2>&1 || {
    echo "❌ Error: No hay credenciales AWS configuradas"
    echo ""
    echo "Ejecuta: aws configure"
    echo ""
    echo "Necesitarás:"
    echo "  - AWS Access Key ID"
    echo "  - AWS Secret Access Key"
    echo "  - Default region (ejemplo: us-east-1)"
    exit 1
}

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ACCOUNT_USER=$(aws sts get-caller-identity --query Arn --output text)

echo "✓ AWS CLI instalado"
echo "✓ jq instalado"
echo "✓ Credenciales AWS configuradas"
echo ""
echo "AWS Account: ${ACCOUNT_ID}"
echo "AWS User:    ${ACCOUNT_USER}"
echo ""

# Mostrar configuración
source "${SCRIPT_DIR}/aws-config.env"

echo "Configuración:"
echo "  Región:           ${AWS_REGION}"
echo "  Tipo EC2:         ${EC2_INSTANCE_TYPE}"
echo "  Nombre instancia: ${EC2_INSTANCE_NAME}"
echo ""

read -p "¿Continuar con la configuración? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelado por el usuario"
    exit 0
fi

echo ""
echo "════════════════════════════════════════"
echo "Paso 1/2: Configurando EC2 Instance"
echo "════════════════════════════════════════"
echo ""

bash "${SCRIPT_DIR}/aws-ec2-setup.sh"

echo ""
echo "════════════════════════════════════════"
echo "Paso 2/2: Configurando CloudFront CDN"
echo "════════════════════════════════════════"
echo ""

read -p "¿Crear distribución de CloudFront? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    bash "${SCRIPT_DIR}/aws-cloudfront-setup.sh"
else
    echo "⏭️  Saltando configuración de CloudFront"
    echo ""
    echo "Puedes ejecutarlo manualmente después:"
    echo "  cd ${SCRIPT_DIR}"
    echo "  ./aws-cloudfront-setup.sh"
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ✓ Configuración completada            ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Mostrar resumen
if [ -f "${SCRIPT_DIR}/ec2-info.txt" ]; then
    source "${SCRIPT_DIR}/ec2-info.txt"

    echo "═══ EC2 Instance ═══"
    echo "Instance ID: ${INSTANCE_ID}"
    echo "Public IP:   ${PUBLIC_IP}"
    echo "Public DNS:  ${PUBLIC_DNS}"
    echo ""
    echo "URLs directas:"
    echo "  HLS:  http://${PUBLIC_DNS}:8080/hls/mystream.m3u8"
    echo "  Stat: http://${PUBLIC_DNS}:8080/stat"
    echo ""
fi

if [ -f "${SCRIPT_DIR}/cloudfront-info.txt" ]; then
    source "${SCRIPT_DIR}/cloudfront-info.txt"

    echo "═══ CloudFront CDN ═══"
    echo "Distribution ID: ${DISTRIBUTION_ID}"
    echo "Domain:          ${DISTRIBUTION_DOMAIN}"
    echo ""
    echo "URLs con HTTPS (para vodlix.cloud):"
    echo "  HLS:  https://${DISTRIBUTION_DOMAIN}/hls/mystream.m3u8"
    echo "  Stat: https://${DISTRIBUTION_DOMAIN}/stat"
    echo ""
fi

echo "═══ OBS Configuration ═══"
if [ -f "${SCRIPT_DIR}/ec2-info.txt" ]; then
    source "${SCRIPT_DIR}/ec2-info.txt"
    echo "Server:     rtmp://${PUBLIC_DNS}:1935/live"
    echo "Stream Key: mystream"
fi
echo ""

echo "═══ Archivos generados ═══"
echo "  ${SCRIPT_DIR}/ec2-info.txt"
[ -f "${SCRIPT_DIR}/cloudfront-info.txt" ] && echo "  ${SCRIPT_DIR}/cloudfront-info.txt"
[ -f "${SCRIPT_DIR}/${EC2_KEY_NAME}.pem" ] && echo "  ${SCRIPT_DIR}/${EC2_KEY_NAME}.pem (SSH key)"
echo ""

echo "Para destruir todos los recursos:"
echo "  cd ${SCRIPT_DIR}"
echo "  ./cleanup-aws.sh"
echo ""
