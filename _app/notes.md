# Notes

## Step 1

1. Build jekyll
2. Run nginx container with the _site contents built by Jekyll

By default, nginx container

- listens on port **80**
- serves the pages from **/usr/share/nginx/html**

```bash
docker run --name cloudrunblog \
    --publish 8080:80 \
    --volume $(pwd)/_site:/usr/share/nginx/html:ro \
    --rm \
    --detach nginx
```

What did we do with this command?

We publish the host port **8080** to forward to port 80 of the container and mount the **_site** directory on the host filesystem into **/usr/share/nginx/html** of the container. **--rm** to automatically remove the container when it exits. **detach** runs the container in background mode so we can have nginx continue to run. 

```text
$ docker ps
CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                  NAMES
d21d68f1e256   nginx     "/docker-entrypoint.…"   21 minutes ago   Up 21 minutes   0.0.0.0:8080->80/tcp   cloudrunblog
```

## Step 2

Taking one step further, lets look at the nginx config file 

The default config file is at **/etc/nginx/nginx.conf** and custom config files are stored at **/etc/nginx/conf.d/**. **/etc/nginx/nginx.conf** can refer the files in  **/etc/nginx/conf.d/** using the include directive. **/etc/nginx/conf.d/default.conf** has the bare minimum config needed to run the nginx container. **server** block specifies the port to listen to and the location to serve the files from.

```text
$ docker exec -it cloudrunblog bash
root@d21d68f1e256:/# ls /etc/nginx/
conf.d  fastcgi_params  mime.types  modules  nginx.conf  scgi_params  uwsgi_params
root@d21d68f1e256:/# ls /etc/nginx/conf.d/
default.conf
root@d21d68f1e256:/# cat /etc/nginx/conf.d/default.conf
˜
```

Making our own config files, so we can tweak the listening port and the root directory when needed.

```Dockerfile
FROM nginx
COPY _app/etc/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY _site /usr/share/nginx/html
```

Build a new image

```text
$ docker build --tag cloudrunblog:v1 .
Sending build context to Docker daemon  1.255MB
Step 1/3 : FROM nginx
 ---> 0e901e68141f
Step 2/3 : COPY _app/etc/nginx/default.conf /etc/nginx/conf.d/default.conf
 ---> 6d32beb721f2
Step 3/3 : COPY _site /usr/share/nginx/html
 ---> 8133a0e2d023
Successfully built 8133a0e2d023
Successfully tagged cloudrunblog:v1

$ docker images
REPOSITORY     TAG       IMAGE ID       CREATED         SIZE
cloudrunblog   v1        8133a0e2d023   6 seconds ago   143MB
nginx          latest    0e901e68141f   6 days ago      142MB
```

Run the image 

```console
$ docker run --name cloudrunblogv1 \
> --publish 4000:80 \
> --rm --detach \
> cloudrunblog:v1
e46b48b303a9aa2cb3faf04431e7d994b01764ad4723b685ba36293eb5a05a15

$ docker ps
CONTAINER ID   IMAGE             COMMAND                  CREATED          STATUS          PORTS                  NAMES
e46b48b303a9   cloudrunblog:v1   "/docker-entrypoint.…"   46 seconds ago   Up 45 seconds   0.0.0.0:4000->80/tcp   cloudrunblogv1
```

### References

[config guide](http://nginx.org/en/docs/beginners_guide.html)
[config file structure](http://nginx.org/en/docs/beginners_guide.html#conf_structure)
