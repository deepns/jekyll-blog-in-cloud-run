#! /bin/bash

# To run a nginx container with the static pages built by Jekyll
docker run --name cloudrunblog \
    --publish 8080:80 \
    --volume $(pwd)/_site:/usr/share/nginx/html:ro \
    --rm \
    --detach nginx
