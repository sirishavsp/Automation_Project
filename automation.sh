#!/bin/bash

set -e

## Updating all packages
echo "STEP 1: UPDATING SYSTEM PACKAGES"
apt update -y

## Web server service status & restart/install if required
echo "STEP 2: WEB SERVER STATUS"
MYNAME="Sirisha"
S3_BUCKET="upgrad-sirisha"
WEB_SERVER=$(service apache2 status)
if [[ $WEB_SERVER == *"active (running)"* ]]; then
	echo "Apache2 exists"
        if service apache2 status | grep -q "Stopping";then
		echo "Apache2 is stopped, starting the service"
		service apache2 start
	else
		echo "Apache2 is running"
	fi
else
	echo "Apache2 is being installed"
	apt install apache2
	sudo service apache2 start
fi

## Archive web server logs and moving to /tmp
echo "STEP 3: ARCHIVE WEB SERVER LOGS"
TIMESTAMP=$(date +"%d%m%Y"-"%H%M%S")
tar -zcf $MYNAME-http-logs-$TIMESTAMP.tar /var/log/apache2/access.log /var/log/apache2/error.log
for f in $(find -name '*.tar')
do
	mv $f /tmp
	echo "Moved tar file $f to tmp"
done

## Push the Web server logs to S3
echo "STEP 4: RECORDING LOGS INTO S3"
aws s3 cp /tmp/${MYNAME}-http-logs-${TIMESTAMP}.tar s3://${S3_BUCKET}/${MYNAME}-httpd-logs-${TIMESTAMP}.tar
