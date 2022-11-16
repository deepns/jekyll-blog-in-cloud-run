#!/bin/bash

# Script pulled from https://learn.microsoft.com/en-us/azure/container-registry/container-registry-auth-aci
# and modified slightly for my convenience.

# This script requires Azure CLI version 2.25.0 or later. Check version with `az --version`.

# Modify for your environment.
# ACR_NAME: The name of your Azure Container Registry
# SERVICE_PRINCIPAL_NAME: Must be unique within your AD tenant
ACR_NAME=${ACR_NAME:-jekyllblog}
SERVICE_PRINCIPAL_NAME=${SERVICE_PRINCIPAL_NAME:-jekyllblogaci}

echo "Creating a service principal $SERVICE_PRINCIPAL_NAME to $ACR_NAME"

# Obtain the full registry ID
ACR_REGISTRY_ID=$(az acr show --name $ACR_NAME --query "id" --output tsv)
echo "ACR_REGISTRY_ID=$ACR_REGISTRY_ID"

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
