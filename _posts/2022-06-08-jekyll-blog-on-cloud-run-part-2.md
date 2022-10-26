---
layout: single
title:  "Running a jekyll static site on GCP Cloud Run - Part 2"
last_modified_at: 2022-10-25T23:20:02-05:00
categories:
    - Tech
tags:
    - programming
    - cloud
    - learning
    - gcp
    - docker
toc: true
header:
  teaser: /assets/images/teasers/jekyll-on-cloud-run.jpg
---

This is continuation of my [previous post](https://www.deepanseeralan.com/tech/hosting-jekyll-site-in-gcp-cloud-run/). This part talks about publishing the jekyll blog container image to container registry, deploying a cloud run service with that image and set up continuous deployment from github repo. (note: all the below commands were run from the google cloud shell instance)

## Build the image

```console
$ docker build --tag gcr.io/$GOOGLE_CLOUD_PROJECT/cloudrunblog:v1 .
Sending build context to Docker daemon  1.321MB
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
 ---> Running in 4092ad57f3f6
Successfully installed bundler-2.3.15
1 gem installed
Removing intermediate container 4092ad57f3f6
 ---> d632f4cee0bc
Step 3/11 : WORKDIR /work
 ---> Running in a88f45db5b51
Removing intermediate container a88f45db5b51
 ---> 81c6a360d828
Step 4/11 : COPY Gemfile* /work/
 ---> 936a5af55fa0
Step 5/11 : RUN bundle install
 ---> Running in 2e488378deb1
Bundler 2.3.15 is running, but your lockfile was generated with 2.3.14. Installing Bundler 2.3.14 and restarting using that version.
Fetching gem metadata from https://rubygems.org/.
Fetching bundler 2.3.14
Installing bundler 2.3.14
Fetching gem metadata from https://rubygems.org/.........
Using bundler 2.3.14
Fetching colorator 1.1.0
Fetching public_suffix 4.0.7
Fetching concurrent-ruby 1.1.10
Fetching eventmachine 1.2.7
Installing colorator 1.1.0
Installing public_suffix 4.0.7
Installing eventmachine 1.2.7 with native extensions
Fetching http_parser.rb 0.8.0
Installing concurrent-ruby 1.1.10
Fetching faraday-net_http 2.0.3
Installing faraday-net_http 2.0.3
Using ruby2_keywords 0.0.5
Fetching ffi 1.15.5
Installing http_parser.rb 0.8.0 with native extensions
Fetching forwardable-extended 2.6.0
Installing ffi 1.15.5 with native extensions
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
Fetching addressable 2.8.0
Installing addressable 2.8.0
Fetching faraday 2.3.0
Installing faraday 2.3.0
Fetching i18n 1.10.0
Installing i18n 1.10.0
Fetching pathutil 0.16.2
Installing pathutil 0.16.2
Fetching kramdown 2.4.0
Installing kramdown 2.4.0
Fetching terminal-table 2.0.0
Installing terminal-table 2.0.0
Fetching sawyer 0.9.1
Installing sawyer 0.9.1
Fetching kramdown-parser-gfm 1.1.0
Installing kramdown-parser-gfm 1.1.0
Fetching octokit 4.23.0
Installing octokit 4.23.0
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
Fetching jekyll-include-cache 0.2.1
Fetching jekyll-seo-tag 2.8.0
Fetching jekyll-sitemap 1.4.0
Installing jekyll-seo-tag 2.8.0
Installing jekyll-include-cache 0.2.1
Installing jekyll-feed 0.16.0
Installing jekyll-sitemap 1.4.0
Fetching minima 2.5.1
Fetching minimal-mistakes-jekyll 4.24.0
Installing minima 2.5.1
Installing minimal-mistakes-jekyll 4.24.0
Bundle complete! 8 Gemfile dependencies, 41 gems now installed.
Use `bundle info [gemname]` to see where a bundled gem is installed.
Removing intermediate container 2e488378deb1
 ---> fba47483cb38
Step 6/11 : COPY . .
 ---> 30927ea099ac
Step 7/11 : ENV JEKYLL_ENV=production
 ---> Running in c15d02262ec3
Removing intermediate container c15d02262ec3
 ---> b69f49561f8d
Step 8/11 : RUN bundle exec jekyll build
 ---> Running in b0c2bb02488d
Configuration file: /work/_config.yml
To use retry middleware with Faraday v2.0+, install `faraday-retry` gem
            Source: /work
       Destination: /work/_site
 Incremental build: disabled. Enable with --incremental
      Generating...
       Jekyll Feed: Generating feed for posts
                    done in 1.449 seconds.
 Auto-regeneration: disabled. Use --watch to enable.
Removing intermediate container b0c2bb02488d
 ---> 6c0ab72680b9
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
 ---> b506e7436fc1
Step 11/11 : COPY _app/etc/nginx/default.conf /etc/nginx/conf.d/default.conf
 ---> 66a186f8c671
Successfully built 66a186f8c671
Successfully tagged gcr.io/cloud-run-experiments-350118/cloudrunblog:v1

$ docker images
REPOSITORY                                         TAG       IMAGE ID       CREATED              SIZE
gcr.io/cloud-run-experiments-350118/cloudrunblog   v1        66a186f8c671   About a minute ago   143MB
ruby                                               latest    5bfd2dfe01e7   7 days ago           892MB
nginx                                              latest    0e901e68141f   7 days ago           142MB
```

- Tagging this to the latest

```console
$ docker image tag gcr.io/$GOOGLE_CLOUD_PROJECT/cloudrunblog:v1 gcr.io/$GOOGLE_CLOUD_PROJECT/cloudrunblog:latest

$ docker images
REPOSITORY                                         TAG       IMAGE ID       CREATED         SIZE
gcr.io/cloud-run-experiments-350118/cloudrunblog   latest    66a186f8c671   2 minutes ago   143MB
gcr.io/cloud-run-experiments-350118/cloudrunblog   v1        66a186f8c671   2 minutes ago   143MB
ruby                                               latest    5bfd2dfe01e7   7 days ago      892MB
nginx                                              latest    0e901e68141f   7 days ago      142MB
```

## Push the image to GCP artifact registry

- Configure docker to push to GCP container registry with `$ gcloud auth configure-docker`
- Push the image with `docker push <IMAGE:TAG>`

(note: I have already moved my container registry to artifact registry, so traffic to gcr.io will be redirected to us-docker.pkg.dev)

```console
$ docker push gcr.io/cloud-run-experiments-350118/cloudrunblog:latest
The push refers to repository [gcr.io/cloud-run-experiments-350118/cloudrunblog]
cbd9f90b5476: Pushed
b1a5dd831e16: Pushed
33e3df466e11: Layer already exists
747b7a567071: Layer already exists
57d3fc88cb3f: Layer already exists
53ae81198b64: Layer already exists
58354abe5f0e: Layer already exists
ad6562704f37: Layer already exists
latest: digest: sha256:a8fcf183d1163167f8dbedc4371a2ccee72379be084fd3384255953a9fd80898 size: 1987

$ gcloud config set artifacts/location us
Updated property [artifacts/location].

$ gcloud config set artifacts/repository gcr.io

$ gcloud artifacts docker tags list 
Listing items under project cloud-run-experiments-350118, location us, repository gcr.io.

TAG: 4dec0d1e704d3c7900ee2353e618e5656a23516f
IMAGE: us-docker.pkg.dev/cloud-run-experiments-350118/us.gcr.io/jekyll-blog-in-cloud-run/cloudrunblog
DIGEST: sha256:a8fcf183d1163167f8dbedc4371a2ccee72379be084fd3384255953a9fd80898
```

## Deploy a cloud run service

- Set the region
  - I chose us-central1, can be from any of the supported [regions](https://cloud.google.com/compute/docs/regions-zones/)
- Deploy the service
  - This can be done from the Cloud Run page on Google Cloud Console or through gcloud CLI as well. Going with **gcloud CLI** as thats what I have been working with. (doing this via cloud console is also equally straightforward)
  - what are the parameters needed?
    - `platform` - can be one of **managed, gke, kubernetes**. Defaults to **managed**, and that's good for this usecase.
    - `allow-unauthenticated` - this is needed to make the container accessible from outside

```console
$ gcloud config set run/region us-central1
Updated property [run/region].

$  gcloud run deploy cloudrunblog \
> --image=gcr.io/$GOOGLE_CLOUD_PROJECT/cloudrunblog:latest \
> --platform=managed \
> --allow-unauthenticated
Deploying container to Cloud Run service [cloudrunblog] in project [cloud-run-experiments-350118] region [us-central1]
OK Deploying new service... Done.
  OK Creating Revision... Initializing project for the current region.
  OK Routing traffic...
  OK Setting IAM Policy...
Done.
Service [cloudrunblog] revision [cloudrunblog-00001-zep] has been deployed and is serving 100 percent of traffic.
Service URL: https://cloudrunblog-sxydtth3hq-uc.a.run.app
```

- can use **gcloud run services describe cloudrunblog** to get a detailed view of the service

## Make edits and publish new version

Just for some fun, doing some minor edits to the posts and publishing a new version.

- Changed the date of the post
- Build again, with a new tag `$ docker build --tag gcr.io/$GOOGLE_CLOUD_PROJECT/cloudrunblog:v2 .`
- Retag v2 to latest `$ docker image tag gcr.io/$GOOGLE_CLOUD_PROJECT/cloudrunblog:v2 gcr.io/$GOOGLE_CLOUD_PROJECT/cloudrunblog:latest`

```console
$ docker images
REPOSITORY                                         TAG       IMAGE ID       CREATED              SIZE
gcr.io/cloud-run-experiments-350118/cloudrunblog   latest    078f42c45c6d   About a minute ago   143MB
gcr.io/cloud-run-experiments-350118/cloudrunblog   v2        078f42c45c6d   About a minute ago   143MB
gcr.io/cloud-run-experiments-350118/cloudrunblog   v1        66a186f8c671   16 minutes ago       143MB
ruby                                               latest    5bfd2dfe01e7   7 days ago           892MB
nginx                                              latest    0e901e68141f   7 days ago           142MB
```

- Push the latest image

```console
$ docker push gcr.io/$GOOGLE_CLOUD_PROJECT/cloudrunblog:latest
The push refers to repository [gcr.io/cloud-run-experiments-350118/cloudrunblog]
8e26bca3dbf8: Pushed
b4171161e9bc: Pushed
33e3df466e11: Layer already exists
747b7a567071: Layer already exists
57d3fc88cb3f: Layer already exists
53ae81198b64: Layer already exists
58354abe5f0e: Layer already exists
ad6562704f37: Layer already exists
latest: digest: sha256:4d0c2e3c190ec538552f253c4062c9e5a9acec0a8396182ce75ddf3bbfa41263 size: 1987

$ gcloud container images list-tags gcr.io/$GOOGLE_CLOUD_PROJECT/cloudrunblog
DIGEST: 4d0c2e3c190e
TAGS: latest

DIGEST: a8fcf183d116
TAGS:
```

- Update the service with the recently pushed image

```console
$ gcloud run services update \
> cloudrunblog \
> --image gcr.io/$GOOGLE_CLOUD_PROJECT/cloudrunblog
OK Deploying... Done.
  OK Creating Revision...
  OK Routing traffic...
Done.
Service [cloudrunblog] revision [cloudrunblog-00002-tod] has been deployed and is serving 100 percent of traffic.
Service URL: https://cloudrunblog-sxydtth3hq-uc.a.run.app
```

- Checking the revisions and making sure that the latest revision is active

```console
$ gcloud run revisions list --service cloudrunblog
✔
REVISION: cloudrunblog-00002-tod
ACTIVE: yes
SERVICE: cloudrunblog
DEPLOYED: 2022-06-05 02:59:48 UTC
DEPLOYED BY: xxxxx.xxxxxxx@gmail.com

✔
REVISION: cloudrunblog-00001-zep
ACTIVE:
SERVICE: cloudrunblog
DEPLOYED: 2022-06-05 02:46:42 UTC
DEPLOYED BY: xxxxxx.xxxxxxx@gmail.com
```

- Clean up the old images

```console
$ gcloud container images list-tags gcr.io/cloud-run-experiments-350118/cloudrunblog
DIGEST: 4d0c2e3c190e
TAGS: latest

DIGEST: a8fcf183d116
TAGS:

$ gcloud container images delete gcr.io/$GOOGLE_CLOUD_PROJECT/cloudrunblog@sha256:a8fcf183d116
Digests:
- gcr.io/cloud-run-experiments-350118/cloudrunblog@sha256:a8fcf183d1163167f8dbedc4371a2ccee72379be084fd3384255953a9fd80898
This operation will delete the tags and images identified by the digests above.

Do you want to continue (Y/n)?  y

Deleted [gcr.io/cloud-run-experiments-350118/cloudrunblog@sha256:a8fcf183d1163167f8dbedc4371a2ccee72379be084fd3384255953a9fd80898].

$ gcloud container images list-tags gcr.io/$GOOGLE_CLOUD_PROJECT/cloudrunblog
DIGEST: 4d0c2e3c190e
TAGS: latest
```

## Configure CI/CD for the Cloud Run service

I followed the steps from [here](https://cloud.google.com/run/docs/continuous-deployment-with-cloud-build#existing-service) to set up continuous deployment for this blog (hosted at https://github.com/deepns/jekyll-blog-in-cloud-run). The steps are fairly straightforward and worked without any trouble. CI/CD works good with Cloud Source Repositories on GCP as well.

- Goto cloud run page
- Set up continuous deployment
- Authenticate with Github
- Add connected repositories
- Specify build configuration (branch and Dockerfile)

Setting up CI/CD creates a Cloud Build trigger to do the following steps when a new commit is pushed to the specified branch (pretty much the same steps as what described in [manual steps](https://cloud.google.com/build/docs/deploying-builds/deploy-cloud-run)). Alternatively this can be achieved with cloudbuild files too.

- Build the image
- Push the image to container registry
- Deploy the image to the service

Exploring the builds

```console
$ gcloud beta builds triggers list
---                                       
build:        
  images:                                                   
  - $_GCR_HOSTNAME/$PROJECT_ID/$REPO_NAME/$_SERVICE_NAME:$COMMIT_SHA
  options:
    substitutionOption: ALLOW_LOOSE
  steps:
  - args:
    - build
    - --no-cache
    - -t
    - $_GCR_HOSTNAME/$PROJECT_ID/$REPO_NAME/$_SERVICE_NAME:$COMMIT_SHA
    - .
    - -f
    - Dockerfile
    id: Build
    name: gcr.io/cloud-builders/docker
  - args:
    - push
    - $_GCR_HOSTNAME/$PROJECT_ID/$REPO_NAME/$_SERVICE_NAME:$COMMIT_SHA
    id: Push
    name: gcr.io/cloud-builders/docker
  - args:
    - run
    - services
    - update
    - $_SERVICE_NAME
    - --platform=managed
    - --image=$_GCR_HOSTNAME/$PROJECT_ID/$REPO_NAME/$_SERVICE_NAME:$COMMIT_SHA
    - --labels=managed-by=gcp-cloud-build-deploy-cloud-run,commit-sha=$COMMIT_SHA,gcb-build-id=$BUILD_ID,gcb-trigger-id=$_TRIGGER_ID,$_LABELS
    - --region=$_DEPLOY_REGION
    - --quiet
    entrypoint: gcloud
    id: Deploy
    name: gcr.io/google.com/cloudsdktool/cloud-sdk:slim
  substitutions:
    _DEPLOY_REGION: us-central1
    _GCR_HOSTNAME: us.gcr.io
    _LABELS: gcb-trigger-id=08a2985a-a449-43f7-bd5b-342b95c90861
    _PLATFORM: managed
    _SERVICE_NAME: cloudrunblog
    _TRIGGER_ID: 08a2985a-a449-43f7-bd5b-342b95c90861
  tags:
  - gcp-cloud-build-deploy-cloud-run
  - gcp-cloud-build-deploy-cloud-run-managed
  - cloudrunblog
createTime: '2022-06-06T11:32:17.951687163Z'
description: Build and deploy to Cloud Run service cloudrunblog on push to "^main$"
github:
  name: jekyll-blog-in-cloud-run
  owner: deepns
  push:
    branch: ^main$
id: 08a2985a-a449-43f7-bd5b-342b95c90861
name: rmgpgab-cloudrunblog-us-central1-deepns-jekyll-blog-in-cloudpph
substitutions:
  _DEPLOY_REGION: us-central1
  _GCR_HOSTNAME: us.gcr.io
  _LABELS: gcb-trigger-id=08a2985a-a449-43f7-bd5b-342b95c90861
  _PLATFORM: managed
  _SERVICE_NAME: cloudrunblog
  _TRIGGER_ID: 08a2985a-a449-43f7-bd5b-342b95c90861
tags:
- gcp-cloud-build-deploy-cloud-run
- gcp-cloud-build-deploy-cloud-run-managed
- cloudrunblog
    
$ gcloud beta builds list --ongoing
ID: 77c565fa-27fe-410d-9054-4784221e4a8a
CREATE_TIME: 2022-06-06T11:32:19+00:00
DURATION: 1M44S
SOURCE: -
IMAGES: -
STATUS: WORKING

$ gcloud beta builds describe 77c565fa-27fe-410d-9054-4784221e4a8a
artifacts:
  images:
  - us.gcr.io/cloud-run-experiments-350118/jekyll-blog-in-cloud-run/cloudrunblog:4dec0d1e704d3c7900ee2353e618e5656a23516f
buildTriggerId: 08a2985a-a449-43f7-bd5b-342b95c90861
createTime: '2022-06-06T11:32:19.768678299Z'
id: 77c565fa-27fe-410d-9054-4784221e4a8a
images:
- us.gcr.io/cloud-run-experiments-350118/jekyll-blog-in-cloud-run/cloudrunblog:4dec0d1e704d3c7900ee2353e618e5656a23516f
logUrl: https://console.cloud.google.com/cloud-build/builds/77c565fa-27fe-410d-9054-4784221e4a8a?project=365657743345
logsBucket: gs://365657743345.cloudbuild-logs.googleusercontent.com
name: projects/365657743345/locations/global/builds/77c565fa-27fe-410d-9054-4784221e4a8a
options:
  dynamicSubstitutions: true
  logging: LEGACY
  pool: {}
  substitutionOption: ALLOW_LOOSE
projectId: cloud-run-experiments-350118
queueTtl: 3600s
source: {}
startTime: '2022-06-06T11:32:20.582660714Z'
status: WORKING
steps:
- args:
  - build
  - --no-cache
  - -t
  - us.gcr.io/cloud-run-experiments-350118/jekyll-blog-in-cloud-run/cloudrunblog:4dec0d1e704d3c7900ee2353e618e5656a23516f
  - .
  - -f
  - Dockerfile
  id: Build
  name: gcr.io/cloud-builders/docker
- args:
  - push
  - us.gcr.io/cloud-run-experiments-350118/jekyll-blog-in-cloud-run/cloudrunblog:4dec0d1e704d3c7900ee2353e618e5656a23516f
  id: Push
  name: gcr.io/cloud-builders/docker
- args:
  - run
  - services
  - update
  - cloudrunblog
  - --platform=managed
  - --image=us.gcr.io/cloud-run-experiments-350118/jekyll-blog-in-cloud-run/cloudrunblog:4dec0d1e704d3c7900ee2353e618e5656a23516f
  - --labels=managed-by=gcp-cloud-build-deploy-cloud-run,commit-sha=4dec0d1e704d3c7900ee2353e618e5656a23516f,gcb-build-id=77c565fa-27fe-410d-9054-4784221e4a8a,gcb-trigger-id=08a2985a-a449-43f7-bd5b-342b95c90861,gcb-trigger-id=08a2985a-a449-43f7-bd5b-342b95c90861
  - --region=us-central1
  - --quiet
  entrypoint: gcloud
  id: Deploy
  name: gcr.io/google.com/cloudsdktool/cloud-sdk:slim
substitutions:
  BRANCH_NAME: main
  COMMIT_SHA: 4dec0d1e704d3c7900ee2353e618e5656a23516f
  REF_NAME: main
  REPO_NAME: jekyll-blog-in-cloud-run
  REVISION_ID: 4dec0d1e704d3c7900ee2353e618e5656a23516f
  SHORT_SHA: 4dec0d1
  TRIGGER_BUILD_CONFIG_PATH: ''
  TRIGGER_NAME: rmgpgab-cloudrunblog-us-central1-deepns-jekyll-blog-in-cloudpph
  _DEPLOY_REGION: us-central1
  _GCR_HOSTNAME: us.gcr.io
  _LABELS: gcb-trigger-id=08a2985a-a449-43f7-bd5b-342b95c90861
  _PLATFORM: managed
  _SERVICE_NAME: cloudrunblog
  _TRIGGER_ID: 08a2985a-a449-43f7-bd5b-342b95c90861
tags:
- gcp-cloud-build-deploy-cloud-run
- gcp-cloud-build-deploy-cloud-run-managed
- cloudrunblog
- trigger-08a2985a-a449-43f7-bd5b-342b95c90861
timeout: 600s

```

- Exploring the service revisions

```console
$ gcloud run services list
✔
SERVICE: cloudrunblog
REGION: us-central1
URL: https://cloudrunblog-sxydtth3hq-uc.a.run.app
LAST DEPLOYED BY: 365657743345@cloudbuild.gserviceaccount.com
LAST DEPLOYED AT: 2022-06-06T11:35:40.358723Z

$ gcloud run revisions list 
✔
REVISION: cloudrunblog-00003-run
ACTIVE: yes
SERVICE: cloudrunblog
DEPLOYED: 2022-06-06 11:35:22 UTC
DEPLOYED BY: 365657743345@cloudbuild.gserviceaccount.com

✔
REVISION: cloudrunblog-00002-tod
ACTIVE:
SERVICE: cloudrunblog
DEPLOYED: 2022-06-05 02:59:48 UTC
DEPLOYED BY: xxxxx.xxxxxxxx@gmail.com

✔
REVISION: cloudrunblog-00001-zep
ACTIVE:
SERVICE: cloudrunblog
DEPLOYED: 2022-06-05 02:46:42 UTC
DEPLOYED BY: xxxxx.xxxxxxxx@gmail.com

$ # get the current image with which the service is running
$ gcloud run services describe cloudrunblog --format=json | jq '.spec.template.spec.containers[].image'
"us.gcr.io/cloud-run-experiments-350118/jekyll-blog-in-cloud-run/cloudrunblog:4dec0d1e704d3c7900ee2353e618e5656a23516f"
```

This turned out to be very fun exercise to play with and get a taste of different GCP components. Its a nice added benefit that all of the above actions can be performed within Google Cloud Shell instance itself, voiding the need to fall back to local machine. Also, this resource usage of the Cloud Run and Artifact Registry in this use case came well under the free limits, so no additional cost incurred in running this deployment.
