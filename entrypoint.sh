#!/bin/bash
set -e

echo "Prepare configuration for script"
TIMESTAMP=$(date +%F_%R)
START_TIMESTAMP=$(date +%s)
TEMP_FILE=temp.sql
BACKUP_FILE=${DB_NAME}-${TIMESTAMP}.sql.gz
BACKUP_FILE_LATEST=${DB_NAME}-latest.sql.gz
DB_HOST=${DB_HOST:-localhost}
DB_PASSWORD=$(cat ${DB_PASSWORD_FILE})
DB_USER=$(cat ${DB_USERNAME_FILE})
CREDENTIALFILE=${CREDENTIALFILE:-/srv/gcloud/credentials.json}
PROM_NAMESPACE=${PROM_NAMESPACE:-kci}

if [ ! -f ${CREDENTIALFILE} ]
then
	echo "Could not find GCloud Service Account credential file under '${CREDENTIALFILE}'"
	echo "Your can set the location by define env['CREDENTIALFILE']"
	exit 1
fi

echo "login to gcloud with SA"
gcloud auth activate-service-account --key-file=/srv/gcloud/credentials.json

# create login credential file
(umask 377 && echo *:5432:*:${DB_USER}:${DB_PASSWORD} >> ~/.pgpass)

echo "Start create backup"
pg_dump -Fc -Z0 -h ${DB_HOST} -p 5432 -U ${DB_USER} ${DB_NAME} -f ${TEMP_FILE}
gzip ${TEMP_FILE}
mv ${TEMP_FILE}.gz ${BACKUP_FILE}
BACKUP_SIZE=$(du ${BACKUP_FILE} | awk '{print $1}')
echo "End backup"

## copy to destination
echo "Copy to gcs"
gsutil cp ${BACKUP_FILE} gs://${GCS_BUCKET}/${DB_NAME}/${BACKUP_FILE} && gsutil cp ${BACKUP_FILE} gs://${GCS_BUCKET}/${DB_NAME}/${BACKUP_FILE_LATEST}

END_TIMESTAMP=$(date +%s)
BACKUP_DURATION=$((END_TIMESTAMP - START_TIMESTAMP))
if [[ ! -z "$PROMETHEUS_PUSH_GATEWAY" ]];
then
echo "sending monitoring metrics to ${PROMETHEUS_PUSH_GATEWAY}"
cat <<EOF | curl -s --data-binary @- http://${PROMETHEUS_PUSH_GATEWAY}/metrics/job/pgdump-gcs/source_type/postgresql/source_name/${DB_NAME}
    # TYPE ${PROM_NAMESPACE}_backup_timestamp counter
    # HELP ${PROM_NAMESPACE}_backup_timestamp Timestamp of last backup run
    ${PROM_NAMESPACE}_backup_timestamp $END_TIMESTAMP
    # TYPE ${PROM_NAMESPACE}_backup_duration gauge
    # HELP ${PROM_NAMESPACE}_backup_duration Time the backup run take until finished
    ${PROM_NAMESPACE}_backup_duration $BACKUP_DURATION
    # TYPE ${PROM_NAMESPACE}_backup_size gauge
    # HELP ${PROM_NAMESPACE}_backup_size Backup Size in bytes
    ${PROM_NAMESPACE}_backup_size $BACKUP_SIZE
EOF
fi
