#!/bin/bash

# Script para actualizar la configuración de CloudFront
# Necesitas tener AWS CLI configurado con las credenciales correctas

DISTRIBUTION_ID="${1}"

if [ -z "$DISTRIBUTION_ID" ]; then
    echo "Error: Debes proporcionar el DISTRIBUTION_ID de CloudFront"
    echo "Uso: $0 <DISTRIBUTION_ID>"
    echo ""
    echo "Para obtener el DISTRIBUTION_ID:"
    echo "  aws cloudfront list-distributions --query 'DistributionList.Items[*].[Id,DomainName,Comment]' --output table"
    exit 1
fi

echo "=========================================="
echo "Actualizando CloudFront Distribution"
echo "=========================================="
echo "Distribution ID: $DISTRIBUTION_ID"
echo ""

# 1. Obtener la configuración actual y el ETag
echo "1. Descargando configuración actual..."
aws cloudfront get-distribution-config --id $DISTRIBUTION_ID > current-config.json

if [ $? -ne 0 ]; then
    echo "Error al obtener la configuración de CloudFront"
    exit 1
fi

# Extraer ETag
ETAG=$(cat current-config.json | jq -r '.ETag')
echo "ETag actual: $ETAG"

# 2. Crear una invalidación de caché para limpiar contenido antiguo
echo ""
echo "2. Creando invalidación de caché..."
aws cloudfront create-invalidation \
    --distribution-id $DISTRIBUTION_ID \
    --paths "/hls/*" "/stat" \
    --query 'Invalidation.[Id,Status,CreateTime]' \
    --output table

# 3. Instrucciones para actualizar manualmente
echo ""
echo "=========================================="
echo "⚠️  SIGUIENTE PASO MANUAL REQUERIDO"
echo "=========================================="
echo ""
echo "Debido a la complejidad de la API de CloudFront, debes actualizar"
echo "la configuración manualmente desde la consola de AWS:"
echo ""
echo "1. Ve a: https://console.aws.amazon.com/cloudfront"
echo "2. Selecciona tu distribución: $DISTRIBUTION_ID"
echo "3. Ve a la pestaña 'Behaviors'"
echo "4. Edita o crea estos behaviors:"
echo ""
echo "   Behavior para /hls/*.m3u8:"
echo "   - Path Pattern: /hls/*.m3u8"
echo "   - TTL: Min=0, Default=1, Max=2"
echo "   - Cache Based on Selected Request Headers:"
echo "     * Origin"
echo "     * Access-Control-Request-Headers"
echo "     * Access-Control-Request-Method"
echo ""
echo "   Behavior para /hls/*.ts:"
echo "   - Path Pattern: /hls/*.ts"
echo "   - TTL: Min=0, Default=5, Max=10"
echo "   - Cache Based on Selected Request Headers:"
echo "     * Origin"
echo "     * Access-Control-Request-Headers"
echo "     * Access-Control-Request-Method"
echo ""
echo "5. Espera que el status cambie a 'Deployed' (~5-10 minutos)"
echo ""
echo "=========================================="
echo "Prueba mientras tanto"
echo "=========================================="
echo ""
echo "URL directa (debería funcionar):"
echo "http://ec2-54-91-19-251.compute-1.amazonaws.com:8080/hls/mystream.m3u8"
echo ""
echo "Puedes probar desde https://interfa.vodlix.cloud/ con esta URL"
echo ""
