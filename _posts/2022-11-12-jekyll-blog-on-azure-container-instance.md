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
---

After playing with hosting a jekyll site on GCP Cloud Run, I was curious to see how similar deployments can be done in other cloud providers. So started my exploration with Azure. Since the site was already built as a container image, I just needed a way to publish the image and run the container. Azure Container Instance offered pretty much what I was looking for.

Assuming that Azure account and subscriptions are set up, these are steps in the workflow needed to deploy a jekyll site in Azure Container Instance.

1. Create a resource group (having a separate resource group for this deployment for easier management)
2. Create a private registry in [Azure Container Registry](https://learn.microsoft.com/en-us/azure/container-registry/)
3. Push the image from local machine to Azure Container Registry
4. Deploy the container
   1. Create a service principal for azure container instance to access the image from the registry
   2. Create the container

In the GCP exercise, I was able to do all the steps from the GCP Cloud Shell VM itself. Truly cloud. Unlike GCP, Cloud Shell VM in Azure Portal had some limitations (e.g. no docker). I used my local machine to build the image and used [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-macos) to access and manage the Azure resources. So from tools perspective, Azure CLI was the only additional thing to install.

Diving into the steps now.

## Create resource group

Creating a new resource group in `eastus` [region](https://azure.microsoft.com/en-gb/explore/global-infrastructure/geographies/#choose-your-region)

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

Creating a new container registry under the resource group just created (`az-learn`)

- `--name` of the registry must be specified in lower case, alpha numeric and globally unique within the Azure Container Registry
- Going with `Basic` sku for this exercise. The default storage (10GB) and image throughput is good enough for this requirement. More about ACR Skus [here](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-skus).

```text
➜  ~ az acr create --resource-group az-learn --name jekyllblogacr --sku Basic --output table
NAME           RESOURCE GROUP    LOCATION    SKU    LOGIN SERVER              CREATION DATE         ADMIN ENABLED
-------------  ----------------  ----------  -----  ------------------------  --------------------  ---------------
jekyllblogacr  az-learn          eastus      Basic  jekyllblogacr.azurecr.io  2022-11-07T04:12:06Z  False
```

## Upload the image to the azure container registry

Image was already built in the using the steps in [previous experiment](https://www.deepanseeralan.com/tech/hosting-jekyll-site-in-gcp-cloud-run/#step-4---building-jekyll-site-and-nginx-image-together). To push the image to the azure container registry, the image tag should be in the right format.

### Tag the image

- Tagging the image in the format `<loginServer>/<imageName>.<tag>`

```text
➜  ~ docker images
REPOSITORY                    TAG       IMAGE ID       CREATED        SIZE
jekyll-blog-aci               v1        e0fbf509394b   2 days ago     143MB

➜  ~ docker image tag jekyll-blog-aci:v1 jekyllblogacr.azurecr.io/jekyll-blog-aci:v1

➜  ~ docker images
REPOSITORY                                 TAG       IMAGE ID       CREATED        SIZE
jekyll-blog-aci                            v1        e0fbf509394b   2 days ago     143MB
jekyllblogacr.azurecr.io/jekyll-blog-aci   v1        e0fbf509394b   2 days ago     143MB
```

### Push the image

Need to login to the registry (using `az acr login`) so **docker push** can do its job.

```text
➜  ~ az acr login --name jekyllblogacr.azurecr.io
The login server endpoint suffix '.azurecr.io' is automatically omitted.
Login Succeeded

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

Followed the steps from [here](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-auth-aci) to create a Azure AD service principal. Modified the script from there slightly to suit my needs.

```bash
#!/bin/bash
# This script requires Azure CLI version 2.25.0 or later. Check version with `az --version`.

# Modify for your environment.
# ACR_NAME: The name of your Azure Container Registry
# SERVICE_PRINCIPAL_NAME: Must be unique within your AD tenant
ACR_NAME=${ACR_NAME:-jekyllblog}
SERVICE_PRINCIPAL_NAME=${SERVICE_PRINCIPAL_NAME:-jekyllblogaci}

echo "Creating a service principal $SERVICE_PRINCIPAL_NAME to $ACR_NAME"

# Obtain the full registry ID
ACR_REGISTRY_ID=$(az acr show --name $ACR_NAME --query "id" --output tsv)
# echo $registryId

# Create the service principal with rights scoped to the registry.
# Default permissions are for docker pull access. Modify the '--role'
# argument value as desired:
# acrpull:     pull only
# acrpush:     push and pull
# owner:       push, pull, and assign roles
PASSWORD=$(az ad sp create-for-rbac \
            --name $SERVICE_PRINCIPAL_NAME \
            --scopes $ACR_REGISTRY_ID \
            --role acrpull \
            --query "password" \
            --output tsv)
USER_NAME=$(az ad sp list \
            --display-name $SERVICE_PRINCIPAL_NAME \
            --query "[].appId" --output tsv)

# Output the service principal's credentials; use these in your services and
# applications to authenticate to the container registry.
echo "Service principal ID: $USER_NAME"
echo "Service principal password: $PASSWORD"
```

```text
➜  ~  ACR_NAME=jekyllblogacr SERVICE_PRINCIPAL_NAME=jekyllblogacr-sp ./_app/az_create_service_principal.sh
Creating a service principal jekyllblogacr-sp to jekyllblogacr
WARNING: Creating 'acrpull' role assignment under scope '/subscriptions/a793422a-8009-48f1-8bb1-b1503391ec61/resourceGroups/az-learn/providers/Microsoft.ContainerRegistry/registries/jekyllblogacr'
WARNING: The output includes credentials that you must protect. Be sure that you do not include these credentials in your code or check the credentials into your source control. For more information, see https://aka.ms/azadsp-cli
Service principal ID: 63c77ba8-946b-4310-ad00-bd8c0bd94f37
Service principal password: YBi8Q~jXpqCLBeuFwZimzKOYHw3rwdQb7ogSxaYT
```

## Create the container instance

Putting together all actions thus far, create a container 

- with image from the azure container registry
- accessed using the Azure AD service principal username and password
- with 1 CPU and 1G of memory (enough for testing purposes)
- with a public IP, exposed at port 80

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

## Cleanup the resources

Most important step! I burnt few dollars leaving my container instances running for a few days.

```text
➜  ~ az group delete --resource-group az-learn
Are you sure you want to perform this operation? (y/n): y
```

Just some sanity checks after deleting the group

```text
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

## Summary

For this particular use case of deploying a jekyll based static site, I found GCP Cloud Run much more suitable than Azure Container Instances. Some observations from my experiments.

- **Resource Allocation**
  - By default, Cloud Run [allocates CPU only](https://cloud.google.com/run/docs/configuring/cpu-allocation) during request processing, container startup and shutdown times. Containers are automatically shutdown after a brief period of no requests (**scale to zero model**). Whereas containers are left running by default in ACI. This directly impacts the billing as well.
  - No significant difference in latency between the Cloud Run and ACI instances during these experiments. This is application specific behavior though. Container startup times will directly impact the first request processing.
- **Cost analysis**
  - GCP free tier was very well sufficient to run these experiments so additional costs incurred. GCP Artifact Registry includes 500MB of storage. With occasional push and pull ops to the artifact registry and ~150MB of container image, free limit of GCP Artifact Registry was never reached.
  - Likewise, Cloud Run access was well within the [free tier limit](https://cloud.google.com/run#section-13). Cloud Run comes with 2 million requests per month and CPU and memory cycles incurred during the request processing were also well within the limit (180000 vCPU seconds/month, 360000 GiB-seconds/month).
  - For the Linux containers, [ACI pricing](https://azure.microsoft.com/en-gb/pricing/details/container-registry/#pricing) charges $0.00445 per GB and $0.04050 per vCPU on the pay-as-you pricing. So it can end up in a $1.08 per day even for a container with bare minimum configuration of 1-vCPU and 1-GB memory. Container registry charges will be separate though.
- **https support**
  - All Cloud Run instances come with a unique HTTPS endpoint in `*.run.app` domain. ACI too comes with a HTTPS endpoint, however the onus falls on the application to manage the TLS connections and certificates. With Cloud Run, this is more transparent as the services can continue to deliver over HTTP in the backend while getting full https support.