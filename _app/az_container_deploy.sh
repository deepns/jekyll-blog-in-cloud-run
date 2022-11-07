AZ_RG=az-learn
AZ_APP_NAME="jekyll-blog-aci"
ACR_LOGIN_SERVER=jekyllblogaci.azurecr.io
APP_IMAGE=$ACR_LOGIN_SERVER/jekyll-blog-aci:v1
ACR_USER=4c97cf4e-5d11-46b3-9b0f-300748692a25
ACR_PASS=yrm8Q~96G0pDwyyRM5TeFOTQau1vlG1w35.4OaCh
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
