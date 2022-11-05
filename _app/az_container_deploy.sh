AZ_RG=az-learn
AZ_APP_NAME="jekyll-blog-aci"
ACR_LOGIN_SERVER=jekyllblogaci.azurecr.io
APP_IMAGE=$ACR_LOGIN_SERVER/jekyll-blog-aci:v1
ACR_USER=ce5c2a23-674b-4473-8c9e-12776b2bd4a8
ACR_PASS=FOzttDqAmc_ZAYpG.dACG8MN1LSHuTucrV
DNS_NAME_LABEL=$AZ_APP_NAME

az container create --resource-group $AZ_RG \
		--name $AZ_APP_NAME \
		--image $APP_IMAGE \
		--cpu 1 --memory 1 \
		--registry-login-server $ACR_LOGIN_SERVER \
		--registry-username $ACR_USER \
		--registry-password $ACR_PASS \
		--ip-address Public \
		--dns-name-label $DNS_NAME_LABEL \
        --ports 80
