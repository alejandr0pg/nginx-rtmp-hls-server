# nginx-rtmp-hls-server
A nginx server with rtmp module for stream video in hls format.<br>
Docker image for an RTMP/HLS server running on nginx<br>
NGINX Version 1.21.1<br>
nginx-rtmp-module Version 1.2.2
<br>
# Steps to run on windows or ubuntu
* Using a ready docker image
1. Download the docker image nginx-rmtp-hls.tar
2. Load this docker image in docker, open a console for that:
<pre>
# docker load < nginx-rmtp-hls.tar
</pre>
3. List your docker images
<pre>
# docker images
</pre>
You will see:
<pre>
REPOSITORY                                TAG       IMAGE ID       CREATED          SIZE
alcarazolabs/nginx-rtmp-hls               latest    f7749de13327   2 minutes ago   17.3MB
</pre>
3.1 IF YOU DON'T WANT TO LOAD THIS file nginx-rmtp-hls.tar AND YOU WANT RUN IT ON RASPBERRY PI or BUILD THE DOCKER IMAGE. RUN:
<pre>
# chmod +x run.sh
# docker image build -t raspberrypi/nginx-rtmp-hls .
</pre>
Note: In this case you should use the file Dockerfile-raspberrypi, rename this file and ignore the default Dockerfile.
<br>
4. Run the server:
<pre>
docker run -p 1935:1935 -p 8080:8080 alcarazolabs/nginx-rtmp-hls
</pre>
5. Start Obs Studio and start a transmision
<pre>
Streaming Service: Custom
Server: rtmp://192.168.0.16:1935/live
Play Path/Stream Key: mystream
</pre>

6. Watching the steam

In your favorite RTMP video player connect to the stream using the URL: <br>
rtmp://192.168.0.16:8080/live/mystream<br>
http://192.168.0.16:8080/hls/mystream.m3u8

# Configurations
This image exposes port 1935 for RTMP Steams and has 2 default channels open "live" and "testing".<br>
live (or your first stream name) is also accessable via HLS on port 8080<br>
It also exposes 8080 so you can access http://<br>
The configuration file is in /opt/nginx/conf/<br>

# Multiple Streams:
You can enable multiple streams on the container by setting RTMP_STREAM_NAMES when launching, This is a comma seperated list of names, E.G.
<pre>
docker run      \
    -p 1935:1935        \
    -p 8080:8080        \
    -e RTMP_STREAM_NAMES=live,teststream1,teststream2   \
    alcarazolabs/nginx-rtmp-hls
</pre>

# Pushing streams
You can ush your main stream out to other RTMP servers, Currently this is limited to only the first stream in RTMP_STREAM_NAMES (default is live) by setting RTMP_PUSH_URLS when launching, This is a comma seperated list of URLS, EG:
<pre>
docker run      \
    -p 1935:1935        \
    -p 8080:8080        \
    -e RTMP_PUSH_URLS=rtmp://live.youtube.com/myname/streamkey,rtmp://live.twitch.tv/app/streamkey
    alcarazolabs/nginx-rmtp-hls
</pre>

# Tested players
* VLC
* Web HLS Player (https://github.com/alcarazolabs/rtmp-hls-player)

# Creds:
https://hub.docker.com/r/jasonrivers/nginx-rtmp
https://github.com/JasonRivers/Docker-nginx-rtmp
# Warning:
The ip 192.168.0.16 must be replace by your machine ip, this is an example ip.
