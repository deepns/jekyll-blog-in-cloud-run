---
layout: single
title:  "Running a jekyll static site on GCP Cloud Run - Part 1"
date:   2022-06-08 08:54:01 +0000
categories: jekyll cloudrun
toc: true
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

## Step 3 - Building a new image from nginx

Putting together the steps in a Dockerfile to build a new nginx image with the site contents. Super simple.

```Dockerfile
# using the latest tag of nginx
FROM nginx
# nginx config file
COPY _app/etc/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY _site /usr/share/nginx/html
```

Run **docker build** (from the root of the workspace) to build a new image

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

Run the newly image **cloudrunblog:v1** in a new container.

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

Steps done so far to serve the site

- Make changes
- Build Jekyll (`bundle exec jekyll build`)
- Build docker image (`docker build --tag <image:tag> .`)
- Run the container in detached mode (`docker run --name <container-name> --publish <host-port:container-port> --detach --rm <image:tag>`)

**Note**: For local testing, **bundle exec jekyll serve** is certainly quicker than the above steps.

Site is now built manually with **jekyll build** and then copied into the docker image. This can be combined together so there is no external dependency. How to go about that?

## Step 4 - Building jekyll site and nginx image together

We need the following to [build](https://jekyllrb.com/docs/) the site.

- ruby
- bundler gem
- bunch of other gems specified in the Gemfile

How to bring them into the docker build steps?

- Use the [ruby image](https://hub.docker.com/_/ruby/)
- Install bundler and required gems in that imag

Updated Dockerfile to build the site with jekyll before packing it into nginx.

```Dockerfile
# using ruby:latest
# naming this stage as jekyll-build
FROM ruby as jekyll-build

# Install bundler gem
RUN gem install bundler

# Set the working directory for subsequent
# RUN, CMD, ADD, COPY and ENTRYPOINT commands
WORKDIR /work

# Copy Gemfile into /work and run bundle install
# to install the required dependencies
COPY Gemfile* /work/
RUN bundle install

# Copy the root contents into /work
COPY . .

# Set necessary environment variables for the build
# and fire off the build
ENV JEKYLL_ENV=production
RUN bundle exec jekyll build

# Now that _site is built in /work directory, take it from 
# jekyll-build stage and put it into /usr/share/nginx/html
# of the nginx image
FROM nginx
COPY --from=jekyll-build  /work/_site /usr/share/nginx/html
COPY _app/etc/nginx/default.conf /etc/nginx/conf.d/default.conf
```

Time to build a new image using the updated Dockerfile.

```console
$ docker build --tag cloudrunblog:v2 .
Sending build context to Docker daemon  1.423MB
Step 1/11 : FROM ruby as jekyll-build
latest: Pulling from library/ruby
e756f3fdd6a3: Pull complete
bf168a674899: Pull complete
e604223835cc: Pull complete
6d5c91c4cd86: Pull complete
2cc8d8854262: Pull complete
93489d0e74dc: Pull complete
d2347a2837e9: Pull complete
1ed399612fd5: Pull complete
Digest: sha256:af018e85cfae54a8d4c803640663e26232f49f31bfbe8b876e678e5365bc13ff
Status: Downloaded newer image for ruby:latest
 ---> 5bfd2dfe01e7
Step 2/11 : RUN gem install bundler
 ---> Running in 0149851db31d
Successfully installed bundler-2.3.15
1 gem installed
Removing intermediate container 0149851db31d
 ---> 1de633fe4669
Step 3/11 : WORKDIR /work
 ---> Running in b8f2cd4cae42
Removing intermediate container b8f2cd4cae42
 ---> 3de004b65a1b
Step 4/11 : COPY Gemfile* /work/
 ---> bf979a32d579
Step 5/11 : RUN bundle install
 ---> Running in 34133f36e7c7
Fetching gem metadata from https://rubygems.org/.........
Using bundler 2.3.15
Fetching eventmachine 1.2.7
Fetching colorator 1.1.0
Fetching concurrent-ruby 1.1.10
Fetching public_suffix 4.0.7

Retrying download gem from https://rubygems.org/ due to error (2/4): Gem::RemoteFetcher::FetchError SocketError: Failed to open TCP connection to rubygems.org:443 (getaddrinfo: Temporary failure in name resolution) (https://rubygems.org/gems/public_suffix-4.0.7.gem)
Installing colorator 1.1.0
Fetching http_parser.rb 0.8.0
Installing eventmachine 1.2.7 with native extensions
Installing concurrent-ruby 1.1.10
Installing http_parser.rb 0.8.0 with native extensions
Fetching faraday-net_http 2.0.3
Installing faraday-net_http 2.0.3
Using ruby2_keywords 0.0.5
Fetching ffi 1.15.5
Installing ffi 1.15.5 with native extensions
Fetching forwardable-extended 2.6.0
Installing forwardable-extended 2.6.0
Fetching rb-fsevent 0.11.1
Installing rb-fsevent 0.11.1
Using rexml 3.2.5
Fetching liquid 4.0.3
Installing liquid 4.0.3
Fetching mercenary 0.4.0
Installing mercenary 0.4.0
Fetching rouge 3.29.0
Installing rouge 3.29.0
Fetching safe_yaml 1.0.5
Installing safe_yaml 1.0.5
Fetching unicode-display_width 1.8.0
Installing unicode-display_width 1.8.0
Fetching jekyll-paginate 1.1.0
Installing jekyll-paginate 1.1.0
Fetching i18n 1.10.0
Installing i18n 1.10.0
Fetching faraday 2.3.0
Installing faraday 2.3.0
Fetching pathutil 0.16.2
Installing pathutil 0.16.2
Fetching kramdown 2.4.0
Installing kramdown 2.4.0
Fetching terminal-table 2.0.0
Installing terminal-table 2.0.0
Fetching kramdown-parser-gfm 1.1.0
Installing kramdown-parser-gfm 1.1.0
Installing public_suffix 4.0.7
Fetching addressable 2.8.0
Installing addressable 2.8.0
Fetching sawyer 0.9.2
Installing sawyer 0.9.2
Fetching octokit 4.24.0
Installing octokit 4.24.0
Fetching jekyll-gist 1.5.0
Installing jekyll-gist 1.5.0
Fetching sassc 2.4.0
Fetching rb-inotify 0.10.1
Installing rb-inotify 0.10.1
Fetching listen 3.7.1
Installing sassc 2.4.0 with native extensions
Installing listen 3.7.1
Fetching jekyll-watch 2.2.1
Installing jekyll-watch 2.2.1
Fetching em-websocket 0.5.3
Installing em-websocket 0.5.3
Fetching jekyll-sass-converter 2.2.0
Installing jekyll-sass-converter 2.2.0
Fetching jekyll 4.2.2
Installing jekyll 4.2.2
Fetching jekyll-feed 0.16.0
Fetching jekyll-sitemap 1.4.0
Fetching jekyll-include-cache 0.2.1
Fetching jekyll-seo-tag 2.8.0
Installing jekyll-include-cache 0.2.1
Installing jekyll-feed 0.16.0
Installing jekyll-sitemap 1.4.0
Installing jekyll-seo-tag 2.8.0
Fetching minima 2.5.1
Fetching minimal-mistakes-jekyll 4.24.0
Installing minima 2.5.1
Installing minimal-mistakes-jekyll 4.24.0
Bundle complete! 8 Gemfile dependencies, 41 gems now installed.
Use `bundle info [gemname]` to see where a bundled gem is installed.
Removing intermediate container 34133f36e7c7
 ---> 2f563fad6280
Step 6/11 : COPY . .
 ---> 4e2d209a6dac
Step 7/11 : ENV JEKYLL_ENV=production
 ---> Running in 8aa5978b752e
Removing intermediate container 8aa5978b752e
 ---> 5c36bdfb0ad1
Step 8/11 : RUN bundle exec jekyll build
 ---> Running in 0761eead120b
Configuration file: /work/_config.yml
To use retry middleware with Faraday v2.0+, install `faraday-retry` gem
            Source: /work
       Destination: /work/_site
 Incremental build: disabled. Enable with --incremental
      Generating...
       Jekyll Feed: Generating feed for posts
                    done in 1.494 seconds.
 Auto-regeneration: disabled. Use --watch to enable.
Removing intermediate container 0761eead120b
 ---> a191d27cfc86
Step 9/11 : FROM nginx
latest: Pulling from library/nginx
42c077c10790: Pull complete
62c70f376f6a: Pull complete
915cc9bd79c2: Pull complete
75a963e94de0: Pull complete
7b1fab684d70: Pull complete
db24d06d5af4: Pull complete
Digest: sha256:2bcabc23b45489fb0885d69a06ba1d648aeda973fae7bb981bafbb884165e514
Status: Downloaded newer image for nginx:latest
 ---> 0e901e68141f
Step 10/11 : COPY --from=jekyll-build  /work/_site /usr/share/nginx/html
 ---> f6643992db4d
Step 11/11 : COPY _app/etc/nginx/default.conf /etc/nginx/conf.d/default.conf
 ---> a51c28a10aa9
Successfully built a51c28a10aa9
Successfully tagged cloudrunblog:v2
```

And run the new image

```console
$ docker images                                                                          
REPOSITORY     TAG       IMAGE ID       CREATED              SIZE
cloudrunblog   v2        a51c28a10aa9   About a minute ago   143MB
ruby           latest    5bfd2dfe01e7   2 weeks ago          892MB
nginx          latest    0e901e68141f   2 weeks ago          142MB

$ docker run --name cloudrunblog-v2 \
> --publish 8080:80 \
> --rm --detach \
> cloudrunblog:v2
18b31dd18b251edd1cf230f2468de370b0f125048585e2b48d142e08b36989f0
```

The following pages were very helpful in learning the above steps

- [Deploying My Blog to Google Cloud Run](https://daniel-azuma.com/blog/2019/07/01/deploying-my-blog-to-google-cloud-run)
- [Cloud Run Tutorial](https://cloud.google.com/community/tutorials/deploy-react-nginx-cloud-run)

The container image built in this step is almost ready to be run in Cloud Run, with one pending change. 
Default port exposed on the containers in Cloud Run is 8080. See [container runtime contract](https://cloud.google.com/run/docs/container-contract). So for now will go with nginx listening on 8080.

```conf
server {
    listen       8080;
    listen  [::]:8080;
    server_name  localhost;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }
}
```

There are some ways to customize this behavior further:

- [Configure](https://cloud.google.com/run/docs/configuring/containers#command-line) the Cloud Run service to listen on required port number.
- Configure the application to listen on the port specified in **$PORT** variable (Cloud Run injects the PORT environment variable into the container). With nginx, we can use nginx config templates to update the config file to listen on port specified in $PORT. More on this later.

Part-2 will be all about exploring Cloud Run, its associated GCP components (Cloud Builds, Container Registry, Artifact Registry, gcloud CLI etc.) and deploy the above image in Cloud Run.
