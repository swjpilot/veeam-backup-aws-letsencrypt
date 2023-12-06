#!/bin/bash
##      .SYNOPSIS
##      SSL Certificate for Veeam Backup for AWS with Let's Encrypt
## 
##      .DESCRIPTION
##      This Script will take the most recent Let's Encrypt certificate and push it to the Veeam Backup for AWS Web Server 
##      The Script, and the whole Let's Encrypt it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##	
##      .Notes
##      NAME:  veeam_aws_ssl.sh
##      ORIGINAL NAME: veeam_aws_ssl.sh
##      PROPERTIES: veeam_aws_ssl.properties
##      LASTEDIT: 12/06/2023
##      VERSION: 2.0
##      KEYWORDS: Veeam, SSL, Let's Encrypt

#Read Properties File with Configuration
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
if [[ -s $SCRIPT_DIR/veeam_aws_ssl.properties ]] 
then
    while read line; do
        export $line
    done < $SCRIPT_DIR/veeam_aws_ssl.properties
else
    echo "Properties File Not found in same directory as script is being executed from"
fi
if [[ "$ACMEecc" == "true" ]]
then
    ecc=$veeamDomain
    ecc+=_ecc
else
    ecc=$veeamDomain
fi

authResp=$(curl -X POST --header "Content-Type: application/x-www-form-urlencoded" --header "Accept: application/json" --header "x-api-version: 1.4-rev0" -d "Username=$veeamUsername&Password=$veeamPassword&grant_type=Password" "$veeamBackupAWSServer:$veeamBackupAWSPortapi/api/v1/token" -k --silent)

echo $authResp

veeamBearer=$(jq -r '.access_token' <<< $authResp)

echo $veeamBearer
##
# Veeam Backup for AWS SSL PFX Certificate Creation. This part will combine Let's Encrypt SSL files into a valid .pfx for Microsoft for AWS
##
openssl pkcs12 -export -out $veeamOutputPFXPath -inkey /root/.acme.sh/$ecc/$veeamDomain.key -in /root/.acme.sh/$ecc/fullchain.cer -password pass:$veeamSSLPassword -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -nomac

##
# Veeam Backup for AWS SSL Certificate Push. This part will retrieve last Let's Encrypt Certificate and push it
##
veeamVBAURL="$veeamBackupAWSServer:$veeamBackupAWSPortapi/api/v1/settings/certificates/upload"

curl -X POST "$veeamVBAURL" -H "accept: application/json" -H "x-api-version: 1.4-rev0" -H "Authorization: Bearer $veeamBearer" -H "Content-Type: multipart/form-data" -F "certificateFile=@$veeamOutputPFXPath;type=application/x-pkcs12" -F "certificatePassword=$veeamSSLPassword" -k

echo "Your Veeam Backup for AWS SSL Certificate has been replaced with a valid Let's Encrypt one. Go to https://$veeamDomain"
