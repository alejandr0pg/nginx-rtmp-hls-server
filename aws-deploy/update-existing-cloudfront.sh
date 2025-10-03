#!/bin/bash

# ============================================
# Actualizar CloudFront existente
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DISTRIBUTION_ID="${1}"

if [ -z "$DISTRIBUTION_ID" ]; then
    echo "Error: Debes proporcionar el DISTRIBUTION_ID"
    echo ""
    echo "Uso: $0 <DISTRIBUTION_ID>"
    echo ""
    echo "Para listar tus distribuciones:"
    echo "  aws cloudfront list-distributions --query 'DistributionList.Items[*].[Id,DomainName,Comment]' --output table"
    echo ""
    exit 1
fi

echo "=========================================="
echo "Actualizando CloudFront Distribution"
echo "=========================================="
echo "Distribution ID: $DISTRIBUTION_ID"
echo ""

# Verificar que existe
echo "1. Verificando distribución..."
aws cloudfront get-distribution --id $DISTRIBUTION_ID > /dev/null 2>&1 || {
    echo "❌ Error: Distribution $DISTRIBUTION_ID no existe"
    exit 1
}

CURRENT_DOMAIN=$(aws cloudfront get-distribution --id $DISTRIBUTION_ID --query 'Distribution.DomainName' --output text)
CURRENT_ORIGIN=$(aws cloudfront get-distribution --id $DISTRIBUTION_ID --query 'Distribution.DistributionConfig.Origins.Items[0].DomainName' --output text)

echo "✓ Distribución encontrada"
echo "  Domain:    $CURRENT_DOMAIN"
echo "  Origin:    $CURRENT_ORIGIN"
echo ""

# Obtener configuración actual
echo "2. Descargando configuración actual..."
aws cloudfront get-distribution-config --id $DISTRIBUTION_ID > /tmp/current-cf-config.json

ETAG=$(cat /tmp/current-cf-config.json | jq -r '.ETag')
echo "✓ ETag: $ETAG"
echo ""

# Crear nueva configuración con los cache behaviors correctos
echo "3. Actualizando configuración de cache behaviors..."

cat /tmp/current-cf-config.json | jq '.DistributionConfig' > /tmp/base-config.json

# Actualizar los cache behaviors
cat /tmp/base-config.json | jq '
.CacheBehaviors.Quantity = 3 |
.CacheBehaviors.Items = [
  {
    "PathPattern": "/hls/*.m3u8",
    "TargetOriginId": .Origins.Items[0].Id,
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "Compress": false,
    "MinTTL": 0,
    "DefaultTTL": 1,
    "MaxTTL": 2,
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      },
      "Headers": {
        "Quantity": 3,
        "Items": ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
      }
    },
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    }
  },
  {
    "PathPattern": "/hls/*.ts",
    "TargetOriginId": .Origins.Items[0].Id,
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "Compress": false,
    "MinTTL": 0,
    "DefaultTTL": 5,
    "MaxTTL": 10,
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      },
      "Headers": {
        "Quantity": 3,
        "Items": ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
      }
    },
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    }
  },
  {
    "PathPattern": "/stat",
    "TargetOriginId": .Origins.Items[0].Id,
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "Compress": false,
    "MinTTL": 0,
    "DefaultTTL": 0,
    "MaxTTL": 1,
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      },
      "Headers": {
        "Quantity": 0
      }
    },
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    }
  }
] |
.DefaultCacheBehavior.ViewerProtocolPolicy = "redirect-to-https" |
.DefaultCacheBehavior.MinTTL = 0 |
.DefaultCacheBehavior.DefaultTTL = 5 |
.DefaultCacheBehavior.MaxTTL = 10 |
.DefaultCacheBehavior.ForwardedValues.Headers = {
  "Quantity": 3,
  "Items": ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
}
' > /tmp/updated-cf-config.json

echo "✓ Configuración actualizada"
echo ""

# Mostrar cambios
echo "Cambios a aplicar:"
echo "  - PathPattern: /hls/*.m3u8 (TTL: 1-2 seg)"
echo "  - PathPattern: /hls/*.ts (TTL: 5-10 seg)"
echo "  - PathPattern: /stat (TTL: 0-1 seg)"
echo "  - ViewerProtocolPolicy: redirect-to-https"
echo "  - Headers CORS habilitados"
echo ""

read -p "¿Continuar? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelado"
    exit 0
fi

# Aplicar cambios
echo "4. Aplicando cambios a CloudFront..."
aws cloudfront update-distribution \
    --id $DISTRIBUTION_ID \
    --distribution-config file:///tmp/updated-cf-config.json \
    --if-match $ETAG > /tmp/update-result.json

NEW_ETAG=$(cat /tmp/update-result.json | jq -r '.ETag')
STATUS=$(cat /tmp/update-result.json | jq -r '.Distribution.Status')

echo "✓ Cambios aplicados"
echo "  Nuevo ETag: $NEW_ETAG"
echo "  Status: $STATUS"
echo ""

# Crear invalidación para limpiar caché
echo "5. Creando invalidación de caché..."
INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --distribution-id $DISTRIBUTION_ID \
    --paths "/hls/*" "/stat" \
    --query 'Invalidation.Id' \
    --output text)

echo "✓ Invalidación creada: $INVALIDATION_ID"
echo ""

echo "=========================================="
echo "✓ CloudFront actualizado exitosamente"
echo "=========================================="
echo ""
echo "Distribution: $CURRENT_DOMAIN"
echo "Status:       $STATUS"
echo ""
echo "⏳ Los cambios tardarán ~5-10 minutos en propagarse"
echo ""
echo "Verificar status:"
echo "  aws cloudfront get-distribution --id $DISTRIBUTION_ID --query 'Distribution.Status'"
echo ""
echo "URL para usar en vodlix.cloud:"
echo "  https://$CURRENT_DOMAIN/hls/mystream.m3u8"
echo ""