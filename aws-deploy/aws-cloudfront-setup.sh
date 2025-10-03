#!/bin/bash

# ============================================
# AWS CloudFront Setup Script para NGINX RTMP/HLS
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/aws-config.env"

# Verificar que existe ec2-info.txt
if [ ! -f "${SCRIPT_DIR}/ec2-info.txt" ]; then
    echo "❌ Error: No se encontró ec2-info.txt"
    echo "Ejecuta primero: ./aws-ec2-setup.sh"
    exit 1
fi

source "${SCRIPT_DIR}/ec2-info.txt"

echo "=========================================="
echo "Configurando CloudFront para NGINX RTMP/HLS"
echo "=========================================="
echo ""
echo "EC2 Origin: ${PUBLIC_DNS}"
echo ""

# Crear configuración de CloudFront
echo "1. Creando configuración de CloudFront..."
cat > "${SCRIPT_DIR}/cloudfront-distribution-config.json" <<EOF
{
  "CallerReference": "nginx-rtmp-hls-$(date +%s)",
  "Comment": "${CLOUDFRONT_COMMENT}",
  "Enabled": true,
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "nginx-ec2-origin",
        "DomainName": "${PUBLIC_DNS}",
        "CustomOriginConfig": {
          "HTTPPort": 8080,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only",
          "OriginSslProtocols": {
            "Quantity": 1,
            "Items": ["TLSv1.2"]
          },
          "OriginReadTimeout": 30,
          "OriginKeepaliveTimeout": 5
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "nginx-ec2-origin",
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
  "CacheBehaviors": {
    "Quantity": 3,
    "Items": [
      {
        "PathPattern": "/hls/*.m3u8",
        "TargetOriginId": "nginx-ec2-origin",
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
        "TargetOriginId": "nginx-ec2-origin",
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
        "TargetOriginId": "nginx-ec2-origin",
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
    ]
  },
  "PriceClass": "${CLOUDFRONT_PRICE_CLASS}"
}
EOF

echo "✓ Configuración creada"
echo ""

# Crear distribución de CloudFront
echo "2. Creando distribución de CloudFront..."
echo "   Esto puede tardar ~5-10 minutos..."

DISTRIBUTION_OUTPUT=$(aws cloudfront create-distribution \
    --distribution-config file://${SCRIPT_DIR}/cloudfront-distribution-config.json \
    --region us-east-1)

DISTRIBUTION_ID=$(echo $DISTRIBUTION_OUTPUT | jq -r '.Distribution.Id')
DISTRIBUTION_DOMAIN=$(echo $DISTRIBUTION_OUTPUT | jq -r '.Distribution.DomainName')
DISTRIBUTION_STATUS=$(echo $DISTRIBUTION_OUTPUT | jq -r '.Distribution.Status')

echo "✓ Distribución creada: ${DISTRIBUTION_ID}"
echo ""

# Guardar información
cat > "${SCRIPT_DIR}/cloudfront-info.txt" <<EOF
DISTRIBUTION_ID=${DISTRIBUTION_ID}
DISTRIBUTION_DOMAIN=${DISTRIBUTION_DOMAIN}
DISTRIBUTION_STATUS=${DISTRIBUTION_STATUS}
ORIGIN_DNS=${PUBLIC_DNS}
CREATED=$(date)
EOF

echo "=========================================="
echo "✓ CloudFront Distribution creada"
echo "=========================================="
echo ""
echo "Distribution ID:     ${DISTRIBUTION_ID}"
echo "CloudFront Domain:   ${DISTRIBUTION_DOMAIN}"
echo "Status:              ${DISTRIBUTION_STATUS}"
echo ""
echo "⏳ La distribución tardará ~5-10 minutos en estar completamente desplegada"
echo ""
echo "Verificar status:"
echo "  aws cloudfront get-distribution --id ${DISTRIBUTION_ID} --query 'Distribution.Status'"
echo ""
echo "URLs finales (cuando Status = Deployed):"
echo "  HLS:  https://${DISTRIBUTION_DOMAIN}/hls/mystream.m3u8"
echo "  Stat: https://${DISTRIBUTION_DOMAIN}/stat"
echo ""
echo "Usa esta URL en vodlix.cloud:"
echo "  https://${DISTRIBUTION_DOMAIN}/hls/mystream.m3u8"
echo ""

# Monitorear deployment
echo "3. Monitoreando deployment de CloudFront..."
echo "   (Presiona Ctrl+C para salir y continuar en background)"
echo ""

while true; do
    STATUS=$(aws cloudfront get-distribution \
        --id ${DISTRIBUTION_ID} \
        --query 'Distribution.Status' \
        --output text)

    echo "   Status: ${STATUS} - $(date +%H:%M:%S)"

    if [ "$STATUS" == "Deployed" ]; then
        echo ""
        echo "✓ CloudFront está completamente desplegado"
        break
    fi

    sleep 30
done

echo ""
echo "=========================================="
echo "🎉 ¡Configuración completada!"
echo "=========================================="
echo ""
echo "URL para usar en vodlix.cloud:"
echo "  https://${DISTRIBUTION_DOMAIN}/hls/mystream.m3u8"
echo ""
echo "Información guardada en:"
echo "  - ${SCRIPT_DIR}/cloudfront-info.txt"
echo "  - ${SCRIPT_DIR}/cloudfront-distribution-config.json"
echo ""
