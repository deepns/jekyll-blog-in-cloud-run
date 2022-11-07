---
layout: single
title:  "Running a jekyll static site on Azure Container Instances"
categories:
    - Tech
tags:
    - programming
    - cloud
    - learning
    - azure
    - docker
toc: true
header:
  teaser: /assets/images/teasers/jekyll-on-cloud-run.jpg
---

Drafting the post

- what is this about? note about azure container instance
- steps to go through (create a flow chart for the below steps)
  - create a resource group
  - create a container registry
  - push the image to container registry
  - create a service principal to container registry
  - create the container image
  - delete the resource group
- cost analysis
  - ACR
  - ACI
- comparison with gcp cloud run

## Create resource group

```text
➜  ~ az group create --name az-learn --location eastus
{
  "id": "/subscriptions/a793422a-8009-48f1-8bb1-b1503391ec61/resourceGroups/az-learn",
  "location": "eastus",
  "managedBy": null,
  "name": "az-learn",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null,
  "type": "Microsoft.Resources/resourceGroups"
}
```

## Create container registry

- `--name` must be specified in lower case, alpha numeric and globally unique within the Azure Container Registry
- `Basic` sku is good enough for this exercise

```text
➜  ~ az acr create --resource-group az-learn --name jekyllblogacr --sku Basic --output table
NAME           RESOURCE GROUP    LOCATION    SKU    LOGIN SERVER              CREATION DATE         ADMIN ENABLED
-------------  ----------------  ----------  -----  ------------------------  --------------------  ---------------
jekyllblogacr  az-learn          eastus      Basic  jekyllblogacr.azurecr.io  2022-11-07T04:12:06Z  False
```

## Upload the image to the azure container registry

### Tag the image

- need to tag the image in the format `<loginServer>/<imageName>.<tag>`

```text
➜  ~ docker images
REPOSITORY                    TAG       IMAGE ID       CREATED        SIZE
jekyll-blog-aci               v1        e0fbf509394b   2 days ago     143MB

➜  ~ docker image tag jekyll-blog-aci:v1 jekyllblogacr.azurecr.io/jekyll-blog-aci:v1
➜  ~ az acr login --name jekyllblogacr.azurecr.io
The login server endpoint suffix '.azurecr.io' is automatically omitted.
Login Succeeded

➜  ~ docker images
REPOSITORY                                 TAG       IMAGE ID       CREATED        SIZE
jekyll-blog-aci                            v1        e0fbf509394b   2 days ago     143MB
jekyllblogacr.azurecr.io/jekyll-blog-aci   v1        e0fbf509394b   2 days ago     143MB
```

### Push the image

```text
➜  ~ docker push jekyllblogacr.azurecr.io/jekyll-blog-aci:v1
The push refers to repository [jekyllblogacr.azurecr.io/jekyll-blog-aci]
7badbf2daded: Pushed
4e995ecc3c08: Pushed
feb57d363211: Pushed
98c84706d0f7: Pushed
4311f0ea1a86: Pushed
6d049f642241: Pushed
3158f7304641: Pushed
fd95118eade9: Pushed
v1: digest: sha256:5a1c587ccffca8af483a4524fe0120b72b9e1b0fc7df3600431b1552991c0d3b size: 1987

➜  ~ az acr repository show-tags --name jekyllblogacr --repository jekyll-blog-aci --output table --detail
CreatedTime                   Digest                                                                   LastUpdateTime                Name    Signed
----------------------------  -----------------------------------------------------------------------  ----------------------------  ------  --------
2022-11-07T04:17:56.3035715Z  sha256:5a1c587ccffca8af483a4524fe0120b72b9e1b0fc7df3600431b1552991c0d3b  2022-11-07T04:17:56.3035715Z  v1      False
```

## Create service principal

```text
➜  ~  ACR_NAME=jekyllblogacr SERVICE_PRINCIPAL_NAME=jekyllblogacr-sp ./_app/az_create_service_principal.sh
Creating a service principal jekyllblogacr-sp to jekyllblogacr
WARNING: Creating 'acrpull' role assignment under scope '/subscriptions/a793422a-8009-48f1-8bb1-b1503391ec61/resourceGroups/az-learn/providers/Microsoft.ContainerRegistry/registries/jekyllblogacr'
WARNING: The output includes credentials that you must protect. Be sure that you do not include these credentials in your code or check the credentials into your source control. For more information, see https://aka.ms/azadsp-cli
Service principal ID: 63c77ba8-946b-4310-ad00-bd8c0bd94f37
Service principal password: YBi8Q~jXpqCLBeuFwZimzKOYHw3rwdQb7ogSxaYT
```

## Create the container instance

Using the service principal details obtained in the previous step, create the container instance

```text
➜  ~ az container list --resource-group az-learn
[]
➜  ~ az container create --resource-group az-learn \
--name jekyllblog-aci \
--image jekyllblogacr.azurecr.io/jekyll-blog-aci:v1 \
--cpu 1 --memory 1 \
--registry-login-server jekyllblogacr.azurecr.io \
--registry-username 63c77ba8-946b-4310-ad00-bd8c0bd94f37 \
--registry-password YBi8Q~jXpqCLBeuFwZimzKOYHw3rwdQb7ogSxaYT \
--ip-address Public \
--dns-name-label jekyllblog-aci \
--ports 80 \
--output table
Name            ResourceGroup    Status    Image                                        IP:ports           Network    CPU/Memory       OsType    Location
--------------  ---------------  --------  -------------------------------------------  -----------------  ---------  ---------------  --------  ----------
jekyllblog-aci  az-learn         Running   jekyllblogacr.azurecr.io/jekyll-blog-aci:v1  20.241.152.103:80  Public     1.0 core/1.0 gb  Linux     eastus

➜  ~ az container list --resource-group az-learn --output table
Name            ResourceGroup    Status     Image                                        IP:ports           Network    CPU/Memory       OsType    Location
--------------  ---------------  ---------  -------------------------------------------  -----------------  ---------  ---------------  --------  ----------
jekyllblog-aci  az-learn         Succeeded  jekyllblogacr.azurecr.io/jekyll-blog-aci:v1  20.241.152.103:80  Public     1.0 core/1.0 gb  Linux     eastus

➜  ~ az container show --resource-group az-learn --name jekyllblog-aci --query "ipAddress.fqdn"
"jekyllblog-aci.eastus.azurecontainer.io"

➜  ~ curl --silent http://jekyllblog-aci.eastus.azurecontainer.io:80/ | head
<!doctype html>
<!--
  Minimal Mistakes Jekyll Theme 4.24.0 by Michael Rose
  Copyright 2013-2020 Michael Rose - mademistakes.com | @mmistakes
  Free for personal and commercial use under the MIT license
  https://github.com/mmistakes/minimal-mistakes/blob/master/LICENSE
-->
<html lang="en" class="no-js">
  <head>
    <meta charset="utf-8">
➜  ~
```

## Cost analysis

## Cleanup the resources

```text
➜  ~ az group delete --resource-group az-learn
Are you sure you want to perform this operation? (y/n): y

➜  ~ # just some sanity checks after deleting the group
➜  ~ az acr list --resource-group az-learn --output table
(ResourceGroupNotFound) Resource group 'az-learn' could not be found.
Code: ResourceGroupNotFound
Message: Resource group 'az-learn' could not be found.

➜  ~ az container list --resource-group az-learn --output table
(ResourceGroupNotFound) Resource group 'az-learn' could not be found.
Code: ResourceGroupNotFound
Message: Resource group 'az-learn' could not be found.
➜  ~
```
