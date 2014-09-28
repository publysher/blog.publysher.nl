#!/bin/sh

docker build -t publysher/blog .

docker stop blog-data blog-nginx
docker rm blog-data blog-nginx

docker run -d -v /etc/nginx -v /usr/share/nginx/html --name blog-data publysher/blog echo "Starting blog volume"
docker run -d --volumes-from blog-data -p 80:80 --name blog-nginx nginx

