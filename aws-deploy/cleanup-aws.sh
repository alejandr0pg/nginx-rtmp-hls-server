#!/bin/bash

# ============================================
# Script de limpieza: Eliminar recursos AWS
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/aws-config.env"

echo ""
echo "⚠️  ¡ADVERTENCIA! ⚠️"
echo ""
echo "Este script eliminará TODOS los recursos AWS creados:"
echo ""

if [ -f "${SCRIPT_DIR}/ec2-info.txt" ]; then
    source "${SCRIPT_DIR}/ec2-info.txt"
    echo "  - EC2 Instance: ${INSTANCE_ID}"
fi

if [ -f "${SCRIPT_DIR}/cloudfront-info.txt" ]; then
    source "${SCRIPT_DIR}/cloudfront-info.txt"
    echo "  - CloudFront Distribution: ${DISTRIBUTION_ID}"
fi

echo "  - Security Group: ${SECURITY_GROUP_NAME}"
echo "  - Key Pair: ${EC2_KEY_NAME}"
echo ""

read -p "¿Estás seguro? Escribe 'DELETE' para confirmar: " CONFIRM
if [ "$CONFIRM" != "DELETE" ]; then
    echo "Cancelado"
    exit 0
fi

echo ""
echo "Eliminando recursos..."
echo ""

# 1. Deshabilitar CloudFront distribution (si existe)
if [ -f "${SCRIPT_DIR}/cloudfront-info.txt" ]; then
    source "${SCRIPT_DIR}/cloudfront-info.txt"

    echo "1. Deshabilitando CloudFront distribution..."

    # Obtener configuración actual
    aws cloudfront get-distribution-config \
        --id ${DISTRIBUTION_ID} > /tmp/cf-config.json

    ETAG=$(cat /tmp/cf-config.json | jq -r '.ETag')

    # Deshabilitar
    cat /tmp/cf-config.json | jq '.DistributionConfig.Enabled = false' | jq '.DistributionConfig' > /tmp/cf-config-disabled.json

    aws cloudfront update-distribution \
        --id ${DISTRIBUTION_ID} \
        --distribution-config file:///tmp/cf-config-disabled.json \
        --if-match ${ETAG} > /dev/null

    echo "   ✓ CloudFront deshabilitado (tardará ~15 minutos en propagarse)"
    echo "   Ejecuta este script nuevamente en 15 minutos para eliminarlo completamente"
    echo ""

    # Verificar si ya está deshabilitado y Deployed
    STATUS=$(aws cloudfront get-distribution --id ${DISTRIBUTION_ID} --query 'Distribution.Status' --output text)
    ENABLED=$(aws cloudfront get-distribution --id ${DISTRIBUTION_ID} --query 'Distribution.DistributionConfig.Enabled' --output text)

    if [ "$STATUS" == "Deployed" ] && [ "$ENABLED" == "False" ]; then
        echo "   CloudFront está deshabilitado y desplegado. Procediendo a eliminar..."

        ETAG=$(aws cloudfront get-distribution-config --id ${DISTRIBUTION_ID} --query 'ETag' --output text)

        aws cloudfront delete-distribution \
            --id ${DISTRIBUTION_ID} \
            --if-match ${ETAG} 2>/dev/null && echo "   ✓ CloudFront eliminado" || echo "   ⏳ CloudFront aún no se puede eliminar, intenta más tarde"
    fi
fi

# 2. Terminar instancia EC2
if [ -f "${SCRIPT_DIR}/ec2-info.txt" ]; then
    source "${SCRIPT_DIR}/ec2-info.txt"

    echo "2. Terminando instancia EC2..."
    aws ec2 terminate-instances \
        --instance-ids ${INSTANCE_ID} \
        --region ${AWS_REGION} > /dev/null

    echo "   Esperando a que la instancia termine..."
    aws ec2 wait instance-terminated \
        --instance-ids ${INSTANCE_ID} \
        --region ${AWS_REGION}

    echo "   ✓ Instancia EC2 terminada"
fi

# 3. Eliminar Security Group
echo "3. Eliminando Security Group..."
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${SECURITY_GROUP_NAME}" \
    --query 'SecurityGroups[0].GroupId' \
    --output text \
    --region ${AWS_REGION} 2>/dev/null || echo "")

if [ ! -z "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
    # Esperar un poco para que EC2 libere el SG
    sleep 10

    aws ec2 delete-security-group \
        --group-id ${SG_ID} \
        --region ${AWS_REGION} 2>/dev/null && echo "   ✓ Security Group eliminado" || echo "   ⚠️  No se pudo eliminar el Security Group (puede estar en uso)"
else
    echo "   Security Group no encontrado (probablemente ya eliminado)"
fi

# 4. Eliminar Key Pair
echo "4. Eliminando Key Pair..."
aws ec2 delete-key-pair \
    --key-name ${EC2_KEY_NAME} \
    --region ${AWS_REGION} 2>/dev/null && echo "   ✓ Key Pair eliminado de AWS" || echo "   Key Pair no encontrado"

if [ -f "${SCRIPT_DIR}/${EC2_KEY_NAME}.pem" ]; then
    read -p "   ¿Eliminar archivo local ${EC2_KEY_NAME}.pem? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm "${SCRIPT_DIR}/${EC2_KEY_NAME}.pem"
        echo "   ✓ Archivo .pem eliminado"
    fi
fi

# 5. Limpiar archivos de información
echo ""
echo "5. Limpiando archivos locales..."
rm -f "${SCRIPT_DIR}/ec2-info.txt"
rm -f "${SCRIPT_DIR}/cloudfront-info.txt"
rm -f "${SCRIPT_DIR}/ec2-userdata.sh"
rm -f "${SCRIPT_DIR}/cloudfront-distribution-config.json"
echo "   ✓ Archivos de información eliminados"

echo ""
echo "════════════════════════════════════════"
echo "✓ Limpieza completada"
echo "════════════════════════════════════════"
echo ""

if [ -f "${SCRIPT_DIR}/cloudfront-info.txt" ]; then
    echo "⚠️  Nota: CloudFront puede tardar hasta 15 minutos en deshabilitarse"
    echo "   Ejecuta este script nuevamente para eliminarlo completamente"
fi

echo ""
