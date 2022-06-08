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
    --detach nginx
```

What did this command do?

- It published the host port **8080** to forward to port 80 of the container and mounted the **_site** directory on the host filesystem into **/usr/share/nginx/html** of the container.
- The option **detach** was used to run the container in background mode so we can have nginx continue to run.  **--rm** was used to automatically remove the container when it exits.

```text
$ docker ps
CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                  NAMES
d21d68f1e256   nginx     "/docker-entrypoint.…"   21 minutes ago   Up 21 minutes   0.0.0.0:8080->80/tcp   cloudrunblog
```