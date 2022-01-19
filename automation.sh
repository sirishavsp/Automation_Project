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
aws s3 cp /tmp/${MYNAME}-http-logs-${TIMESTAMP}.tar s3://${S3_BUCKET}/${MYNAME}-httpd-logs-${TIMESTAMP}.ta

## Adding inventory file for Web Server
echo "STEP 5: BOOKKEEPING LOGS"
INVENTORY_FILE=/var/www/html/inventory.html
FILE_SIZE=$(ls -lh /tmp/${MYNAME}-http-logs-${TIMESTAMP}.tar | awk '{print  $5}')
if [ -f "$INVENTORY_FILE" ]; then
	echo "Inventory File exists. Recording into the inventory now."
	echo "httpd-logs	${TIMESTAMP}		tar	${FILE_SIZE}" >> ${INVENTORY_FILE}
else
	echo "Inventory file not found. Creating inventory.html for web server and Recording the logs into it..."
	touch ${INVENTORY_FILE} && echo "Log_Type	Time_Created		Type	Size" >> ${INVENTORY_FILE} && echo "httpd-logs      ${TIMESTAMP}         tar     ${FILE_SIZE}" >> ${INVENTORY_FILE}
fi

## Schedule and Check CronJob Status
echo "STEP 6: CHECK/SCHEDULE CRONJOB"
CRON_PATH=/etc/cron.d/automation
if [ -f "$CRON_PATH" ]; then
  echo "Cron Job is scheduled."
else
  echo "Cron Job is not scheduled. Setting up the CronJob now..."
  touch ${CRON_PATH} && echo "0 1 * * * root /root/Automation_Project/automation.sh" >> ${CRON_PATH}
fi

