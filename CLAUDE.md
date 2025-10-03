# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker-based NGINX RTMP/HLS streaming server that enables real-time video streaming. The server accepts RTMP input streams and converts them to HLS format for playback across various devices and platforms.

**Core Components:**
- NGINX 1.21.1 with RTMP module v1.2.2
- Alpine Linux base image (multi-stage build for minimal size)
- Dynamic configuration via environment variables
- Support for multiple platforms (Ubuntu, Raspberry Pi, Jetson Orin Nano)

## Architecture

### Multi-Stage Docker Build
The project uses a two-stage build process (Dockerfile:1-68):
1. **Builder stage**: Compiles NGINX from source with the RTMP module
2. **Runtime stage**: Creates minimal Alpine image with only runtime dependencies

### Configuration System
The `run.sh` script (run.sh:1-134) dynamically generates the NGINX configuration at container startup:
- Creates `/opt/nginx/conf/nginx.conf` from environment variables
- Configures RTMP streams based on `RTMP_STREAM_NAMES`
- Sets up HLS output (only for the first stream)
- Configures push destinations via `RTMP_PUSH_URLS`

### Network Architecture
- **Port 1935**: RTMP input (streaming from sources like OBS)
- **Port 8080**: HTTP server for HLS playback and statistics
  - `/hls/*.m3u8`: HLS playlist files
  - `/stat`: RTMP statistics page
  - `/control`: RTMP control interface

## Building and Running

### Standard Build (Ubuntu/x86)
```bash
docker build -t alcarazolabs/nginx-rtmp-hls .
docker run -p 1935:1935 -p 8080:8080 alcarazolabs/nginx-rtmp-hls
```

### Raspberry Pi Build
The Raspberry Pi requires Alpine 3.12 (not latest) due to compatibility issues. Use `Dockerfile-raspberry-pi`:
```bash
docker build -f Dockerfile-raspberry-pi -t raspberrypi/nginx-rtmp-hls .
docker run -p 1935:1935 -p 8080:8080 raspberrypi/nginx-rtmp-hls
```

### Jetson Orin Nano
Requires host networking mode due to security constraints:
```bash
sudo docker run --network host -p 1935:1935 -p 8080:8080 jetson/nginx-rtmp-hls
```

### Using Pre-built Image
```bash
docker load < nginx-rtmp-hls.tar
docker images  # Verify the image loaded
docker run -p 1935:1935 -p 8080:8080 alcarazolabs/nginx-rtmp-hls
```

## Configuration Options

### Multiple Streams
Set `RTMP_STREAM_NAMES` as comma-separated stream names (default: "live,testing"):
```bash
docker run -p 1935:1935 -p 8080:8080 \
  -e RTMP_STREAM_NAMES=live,teststream1,teststream2 \
  alcarazolabs/nginx-rtmp-hls
```

**Note**: HLS output is only enabled for the first stream in the list (run.sh:96-104).

### Push to External Services
Set `RTMP_PUSH_URLS` to forward the first stream to external RTMP servers:
```bash
docker run -p 1935:1935 -p 8080:8080 \
  -e RTMP_PUSH_URLS=rtmp://live.youtube.com/app/streamkey,rtmp://live.twitch.tv/app/streamkey \
  alcarazolabs/nginx-rtmp-hls
```

### Connection Limit
Set `RTMP_CONNECTIONS` to control worker connections (default: 1024):
```bash
docker run -p 1935:1935 -p 8080:8080 \
  -e RTMP_CONNECTIONS=2048 \
  alcarazolabs/nginx-rtmp-hls
```

## Streaming and Playback

### Publishing Streams (OBS Studio)
- **Streaming Service**: Custom
- **Server**: `rtmp://<SERVER_IP>:1935/live`
- **Stream Key**: `mystream` (or any key)

### Playback URLs
- **RTMP**: `rtmp://<SERVER_IP>:1935/live/mystream`
- **HLS**: `http://<SERVER_IP>:8080/hls/mystream.m3u8`
- **Statistics**: `http://<SERVER_IP>:8080/stat`

## Platform-Specific Notes

### Raspberry Pi
- Must use Alpine 3.12 base image (Dockerfile-raspberry-pi:5)
- Newer Alpine versions have compatibility issues

### Jetson Orin Nano
- Requires `--network host` flag to bypass Docker networking restrictions
- Security constraints prevent standard bridge networking

## File Structure
- `Dockerfile`: Standard x86/Ubuntu build
- `Dockerfile-raspberry-pi`: ARM-specific build with Alpine 3.12
- `run.sh`: Entrypoint script that generates NGINX config and starts server
- `nginx-rtmp-hls.tar`: Pre-built Docker image for quick deployment
