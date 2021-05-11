# pgdump-gcs

Small docker container for creating a backup of a psql database and put the dump file on a google cloud storage bucket.

## how to use

```bash
docker run \
  -v ./cred:/cred \
  -e DB_HOST={db host addess} \
  -e DB_NAME={database-name} \
  -e DB_PASSWORD_FILE=/cred/my_db_pass_as_file \
  -e DB_USERNAME_FILE=/cred/my_db_user_as_file \
  -e CREDENTIALFILE=/cred/credential.json \
  -e GCS_BUCKET={bucket_name} \
  -e PROM_NAMESPACE=kci \
  kloeckneri/pgdump-gcs:postgres-11
```

## tipps

- create a lifecycle rule to keep your gcs bucket small
- we create also a `_latest` file, so able to access the latest backup with another script

## monitoring

Simple curl pushing some basic parameter to a prometheus push gateway.

### metrics
* timestamp
* duration
* size

### labels
* job = pgdump-gcs
* source_type = postgresql
* source_name = `${DB_NAME}`
