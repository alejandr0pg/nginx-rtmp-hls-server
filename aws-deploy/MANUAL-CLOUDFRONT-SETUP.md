# Configuración Manual de CloudFront para NGINX RTMP/HLS

## Tu CloudFront Distribution

- **Distribution ID:** `E1B0QG62MQSEGO`
- **Domain:** `d1u87stwveh7cm.cloudfront.net`
- **Origin:** `ec2-54-91-19-251.compute-1.amazonaws.com`
- **Status:** Deployed

## URL final para vodlix.cloud

```
https://d1u87stwveh7cm.cloudfront.net/hls/mystream.m3u8
```

---

## Pasos para configurar manualmente

### 1. Acceder a CloudFront Console

1. Ve a: https://console.aws.amazon.com/cloudfront
2. Busca la distribución: `E1B0QG62MQSEGO`
3. Click en el ID para abrir los detalles

### 2. Configurar Behaviors (Cache Behaviors)

Ve a la pestaña **"Behaviors"** y configura 3 behaviors:

---

#### Behavior 1: Playlist HLS (*.m3u8)

1. Click en **"Create behavior"**
2. Configura:

```
Path pattern:                    /hls/*.m3u8
Origin or origin group:          [Selecciona tu origin EC2]
Viewer protocol policy:          Redirect HTTP to HTTPS
Allowed HTTP methods:            GET, HEAD
Cache key and origin requests:   Cache policy and origin request policy (recommended)
```

3. En **Cache policy**, selecciona **"Create policy"**:
   - Policy name: `HLS-Playlist-Policy`
   - Minimum TTL: `0`
   - Maximum TTL: `2`
   - Default TTL: `1`
   - Cache based on: Selected request headers
     - ✅ Origin
     - ✅ Access-Control-Request-Headers
     - ✅ Access-Control-Request-Method

4. Click **"Create behavior"**

---

#### Behavior 2: Segmentos HLS (*.ts)

1. Click en **"Create behavior"**
2. Configura:

```
Path pattern:                    /hls/*.ts
Origin or origin group:          [Selecciona tu origin EC2]
Viewer protocol policy:          Redirect HTTP to HTTPS
Allowed HTTP methods:            GET, HEAD
Cache key and origin requests:   Cache policy and origin request policy (recommended)
```

3. En **Cache policy**, selecciona **"Create policy"**:
   - Policy name: `HLS-Segments-Policy`
   - Minimum TTL: `0`
   - Maximum TTL: `10`
   - Default TTL: `5`
   - Cache based on: Selected request headers
     - ✅ Origin
     - ✅ Access-Control-Request-Headers
     - ✅ Access-Control-Request-Method

4. Click **"Create behavior"**

---

#### Behavior 3: Statistics (/stat)

1. Click en **"Create behavior"**
2. Configura:

```
Path pattern:                    /stat
Origin or origin group:          [Selecciona tu origin EC2]
Viewer protocol policy:          Redirect HTTP to HTTPS
Allowed HTTP methods:            GET, HEAD
Cache key and origin requests:   Cache policy and origin request policy (recommended)
```

3. En **Cache policy**, selecciona **"Create policy"**:
   - Policy name: `NGINX-Stats-Policy`
   - Minimum TTL: `0`
   - Maximum TTL: `1`
   - Default TTL: `0`

4. Click **"Create behavior"**

---

### 3. Ajustar Default Behavior

1. En la pestaña **"Behaviors"**, selecciona **"Default (*)"**
2. Click **"Edit"**
3. Configura:

```
Viewer protocol policy:          Redirect HTTP to HTTPS
Cache key and origin requests:   Cache policy and origin request policy (recommended)
```

4. En **Cache policy**, usa o crea:
   - Minimum TTL: `0`
   - Maximum TTL: `10`
   - Default TTL: `5`

5. Click **"Save changes"**

---

### 4. Configurar Origin (Verificar configuración)

1. Ve a la pestaña **"Origins"**
2. Selecciona tu origin EC2 y click **"Edit"**
3. Verifica:

```
Protocol:                        HTTP only
HTTP port:                       8080
HTTPS port:                      443
```

4. Click **"Save changes"**

---

### 5. Invalidar Caché

1. Ve a la pestaña **"Invalidations"**
2. Click **"Create invalidation"**
3. En **Object paths**, ingresa:

```
/hls/*
/stat
```

4. Click **"Create invalidation"**

---

### 6. Esperar a que se propague

- Los cambios tardarán **5-10 minutos** en propagarse
- El status debe permanecer en **"Deployed"**
- La invalidación tardará **~2-5 minutos**

---

## Verificar configuración

### Opción 1: Desde tu navegador

Abre estas URLs:

```
https://d1u87stwveh7cm.cloudfront.net/stat
https://d1u87stwveh7cm.cloudfront.net/hls/mystream.m3u8
```

### Opción 2: Desde terminal

```bash
# Verificar playlist
curl -I https://d1u87stwveh7cm.cloudfront.net/hls/mystream.m3u8

# Debe retornar HTTP 200 con headers:
# - cache-control: no-cache
# - access-control-allow-origin: *
```

---

## Usar en vodlix.cloud

Una vez configurado, usa esta URL en vodlix.cloud:

```
https://d1u87stwveh7cm.cloudfront.net/hls/mystream.m3u8
```

✅ **Esto resolverá el error de Mixed Content** porque ahora es HTTPS

---

## Troubleshooting

### Error 403 o 404

**Causa:** Caché antiguo o behaviors mal configurados

**Solución:**
1. Verifica que los path patterns sean exactamente: `/hls/*.m3u8`, `/hls/*.ts`, `/stat`
2. Crea una nueva invalidación con path `/hls/*`
3. Espera 5 minutos

### Error de CORS

**Causa:** Headers CORS no están siendo forwarded

**Solución:**
1. Ve a cada behavior
2. En Cache policy, asegúrate de tener estos headers:
   - Origin
   - Access-Control-Request-Headers
   - Access-Control-Request-Method

### Still shows HTTP error

**Causa:** El navegador tiene caché del error anterior

**Solución:**
1. Abre ventana de incógnito
2. O limpia caché del navegador (Cmd+Shift+R en Mac, Ctrl+Shift+R en Windows)

---

## Resumen de configuración correcta

| Path Pattern | TTL (seg) | Headers CORS | HTTPS |
|--------------|-----------|--------------|-------|
| `/hls/*.m3u8` | 1-2 | ✅ | ✅ |
| `/hls/*.ts` | 5-10 | ✅ | ✅ |
| `/stat` | 0-1 | ❌ | ✅ |
| Default `*` | 5-10 | ✅ | ✅ |

---

## Configuración alternativa: Usar CLI (más rápido)

Si prefieres usar el script que creamos:

```bash
cd aws-deploy
./update-existing-cloudfront.sh E1B0QG62MQSEGO
```

Esto aplicará todos los cambios automáticamente en ~30 segundos.
