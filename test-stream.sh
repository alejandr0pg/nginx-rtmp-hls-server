#!/bin/bash

EC2_HOST="ec2-54-91-19-251.compute-1.amazonaws.com"
STREAM_NAME="${1:-mystream}"

echo "=========================================="
echo "Probando servidor NGINX RTMP/HLS"
echo "=========================================="
echo ""

echo "1. Verificando estadísticas NGINX..."
echo "URL: http://${EC2_HOST}:8080/stat"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://${EC2_HOST}:8080/stat
echo ""

echo "2. Verificando archivo HLS playlist (.m3u8)..."
echo "URL: http://${EC2_HOST}:8080/hls/${STREAM_NAME}.m3u8"
PLAYLIST_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://${EC2_HOST}:8080/hls/${STREAM_NAME}.m3u8)
echo "HTTP Status: ${PLAYLIST_STATUS}"

if [ "$PLAYLIST_STATUS" = "200" ]; then
    echo ""
    echo "✓ Contenido del playlist:"
    curl -s http://${EC2_HOST}:8080/hls/${STREAM_NAME}.m3u8
    echo ""
    echo ""
    echo "3. Verificando segmentos .ts..."
    FIRST_TS=$(curl -s http://${EC2_HOST}:8080/hls/${STREAM_NAME}.m3u8 | grep -E "\.ts$" | head -1)
    if [ -n "$FIRST_TS" ]; then
        echo "Probando segmento: $FIRST_TS"
        TS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://${EC2_HOST}:8080/hls/${FIRST_TS})
        echo "HTTP Status: ${TS_STATUS}"
        if [ "$TS_STATUS" = "200" ]; then
            echo "✓ Segmentos HLS disponibles"
        else
            echo "✗ Error al obtener segmento .ts"
        fi
    else
        echo "✗ No se encontraron segmentos .ts en el playlist"
    fi
else
    echo "✗ El archivo .m3u8 no está disponible"
    echo ""
    echo "Posibles causas:"
    echo "  - OBS no está enviando stream al servidor"
    echo "  - El stream name en OBS no coincide con '${STREAM_NAME}'"
    echo "  - El servidor NGINX no está corriendo"
fi

echo ""
echo "=========================================="
echo "URLs para reproducir:"
echo "=========================================="
echo "RTMP: rtmp://${EC2_HOST}:1935/live/${STREAM_NAME}"
echo "HLS:  http://${EC2_HOST}:8080/hls/${STREAM_NAME}.m3u8"
echo "Stat: http://${EC2_HOST}:8080/stat"
echo ""