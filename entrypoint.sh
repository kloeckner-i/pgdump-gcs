#!/bin/bash
set -euo pipefail

echo "Prepare configuration for script"
TIMESTAMP=$(date +%F_%H-%M)
START_TIMESTAMP=$(date +%s)

BACKUP_FILE=${DB_NAME}-${TIMESTAMP}.dump.gz
BACKUP_FILE_LATEST=${DB_NAME}-latest.dump.gz

DB_HOST=${DB_HOST:-localhost}
DB_PASSWORD=$(cat ${DB_PASSWORD_FILE})
DB_USER=$(cat ${DB_USERNAME_FILE})
CREDENTIALFILE=${CREDENTIALFILE:-/srv/gcloud/credentials.json}
PROM_NAMESPACE=${PROM_NAMESPACE:-kci}

if [ ! -f "${CREDENTIALFILE}" ]; then
  echo "Missing GCloud credentials at ${CREDENTIALFILE}"
  exit 1
fi

echo "login to gcloud with SA"
gcloud auth activate-service-account --key-file="${CREDENTIALFILE}"

# pg auth
echo "*:5432:*:${DB_USER}:${DB_PASSWORD}" > ~/.pgpass
chmod 600 ~/.pgpass

echo "Start streaming backup"

# SINGLE STREAM for the backup
pg_dump -Fc -Z0 -h "${DB_HOST}" -p 5432 -U "${DB_USER}" "${DB_NAME}" \
| gzip \
| gsutil -o "GSUtil:parallel_composite_upload_threshold=150M" \
  cp - "gs://${GCS_BUCKET}/${DB_NAME}/${BACKUP_FILE}"

echo "Primary backup uploaded"

# Copy inside GCS just to be sure that is reliable and failsafe
gsutil cp \
  "gs://${GCS_BUCKET}/${DB_NAME}/${BACKUP_FILE}" \
  "gs://${GCS_BUCKET}/${DB_NAME}/${BACKUP_FILE_LATEST}"

echo "Latest backup updated"

# Verify backup exists
gsutil stat "gs://${GCS_BUCKET}/${DB_NAME}/${BACKUP_FILE}" >/dev/null

END_TIMESTAMP=$(date +%s)
BACKUP_DURATION=$((END_TIMESTAMP - START_TIMESTAMP))

echo "Backup finished in ${BACKUP_DURATION}s"