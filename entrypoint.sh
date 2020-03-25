#!/bin/bash
set -e

echo "Prepare configuration for script"
TIMESTAMP=$(date +%F_%R)
BACKUP_FILE=${DB_NAME}-${TIMESTAMP}.sql.gz
BACKUP_FILE_LATEST=${DB_NAME}-latest.sql.gz
DB_HOST=${DB_HOST:-localhost}
DB_PASSWORD=$(cat ${DB_PASSWORD_FILE})
DB_USER=$(cat ${DB_USERNAME_FILE})
CREDENTIALFILE=${CREDENTIALFILE:-/srv/gcloud/credentials.json}

if [ ! -f ${CREDENTIALFILE} ]
then
	echo "Could not find GCloud Service Account credential file under '${CREDENTIALFILE}'"
	echo "Your can set the location by define env['CREDENTIALFILE']"
	exit 1
fi

echo "login to gcloud with SA"
gcloud auth activate-service-account --key-file=/srv/gcloud/credentials.json

# create login credential file
echo *:5432:*:${DB_USER}:${DB_PASSWORD} >> ~/.pgpass
chmod 0600 ~/.pgpass

echo "Start create backup"
pg_dump -F c -Z 9 -h ${DB_HOST} -p 5432 -U ${DB_USER} ${DB_NAME} -f ${BACKUP_FILE}
echo "End backup"

## copy to destination
echo "Copy to gcs"
gsutil cp ${BACKUP_FILE} gs://${GCS_BUCKET}/${DB_NAME}/${BACKUP_FILE} && gsutil cp ${BACKUP_FILE} gs://${GCS_BUCKET}/${DB_NAME}/${BACKUP_FILE_LATEST}

if test $? -ne 0 
then
	exit 1;
fi