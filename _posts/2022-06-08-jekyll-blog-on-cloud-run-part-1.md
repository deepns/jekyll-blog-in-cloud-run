---
layout: single
title:  "Running a jekyll static site on GCP Cloud Run - Part 1"
date:   2022-06-08 08:54:01 +0000
categories: jekyll cloudrun
---

Documenting the steps that I went through recently to run a static site (built using jekyll) on Cloud Run in GCP. 

GitHub also provides free web hosting for static sites. Then why Cloud Run?

- Want to explore and learn more in GCP
- Curious to see options other than GitHub free hosting.
- Have more control on hosting the site for free or at a cheap cost.
- Cloud Run makes it so easy to deploy containerized applications with a pay per use model. The intended site is expected to receive traffic much less than free tier of Cloud Run. 
- Kill some time

## Step 1 - Getting started with nginx container

To deploy in Cloud Run, site needed to be containerized first. So starting with that.

Jekyll build places the static site contents into **_site** directory by default. Using nginx to serve those contents (followed the steps from [nginx docker image](https://hub.docker.com/_/nginx) to get started).

Some basics about nginx default options:

- listens on port **80**
- serves the pages from **/usr/share/nginx/html**

Ran an nginx container with the below command.

```bash
docker run --name cloudrunblog \
    --publish 8080:80 \
    --volume $(pwd)/_site:/usr/share/nginx/html:ro \
    --rm \
    --detach \
    nginx
```

What did this command do?

- It published the host port **8080** to forward to port 80 of the container and mounted the **_site** directory on the host filesystem into **/usr/share/nginx/html** of the container.
- The option **detach** was used to run the container in background mode so we can have nginx continue to run.  **--rm** was used to automatically remove the container when it exits.

```text
$ docker ps
CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                  NAMES
d21d68f1e256   nginx     "/docker-entrypoint.…"   21 minutes ago   Up 21 minutes   0.0.0.0:8080->80/tcp   cloudrunblog
```

## Step 2 - Exploring nginx config

Taking one step further, tried to look at the nginx configuration options.

- The default config file is at **/etc/nginx/nginx.conf** and custom config files are stored at **/etc/nginx/conf.d/**. 
- **/etc/nginx/nginx.conf** can import the configuration from the files in  **/etc/nginx/conf.d/** using the include directive.
- **/etc/nginx/conf.d/default.conf** has the bare minimum config needed to run the nginx container. 
    - **server** block specifies the port to listen to and the location to serve the files from. This is similar to virtual server in Apache configuration.
- [config guide](http://nginx.org/en/docs/beginners_guide.html) and [config file structure](http://nginx.org/en/docs/beginners_guide.html#conf_structure) was very helpful here.


```text
$ docker exec -it cloudrunblog bash
root@d21d68f1e256:/# ls /etc/nginx/
conf.d  fastcgi_params  mime.types  modules  nginx.conf  scgi_params  uwsgi_params
root@d21d68f1e256:/# ls /etc/nginx/conf.d/
default.conf
root@d21d68f1e256:/# cat /etc/nginx/conf.d/default.conf
```

To customize the listening port and the root directory, we need to provide our own config files. So made a copy of  **/etc/nginx/conf.d/default.conf** for future edits.

```conf
server {
    listen       80;
    listen  [::]:80;
    server_name  localhost;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }
}
```

Now that we have our config file and the static contents, its time to put together into a docker image based from nginx and run it as a new container.


## Step 3 - Building a new image

Putting together the steps in a Dockerfile. Super simple.

```Dockerfile
# using the latest tag of nginx
FROM nginx
COPY _app/etc/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY _site /usr/share/nginx/html
```

Using **docker build** to build a new image

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

Running the image **cloudrunblog:v1** in a new container.

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