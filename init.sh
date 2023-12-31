set -e
if [ -z "$MONGODB_ADMIN_ADDRESS" ]; then
  echo "MONGODB_ADMIN_ADDRESS is not set"
  exit 1
else
  echo "MONGODB_ADMIN_ADDRESS is set to $MONGODB_ADMIN_ADDRESS"
fi


if [ -z "$ELASTICSEARCH_ADMIN_ADDRESS" ]; then
  echo "ELASTICSEARCH_ADMIN_ADDRESS is not set"
  exit 1
else
  echo "ELASTICSEARCH_ADMIN_ADDRESS is set to $ELASTICSEARCH_ADMIN_ADDRESS"
fi


if [ -z "$MINIO_EXTERNAL_ADDRESS" ]; then
  echo "MINIO_EXTERNAL_ADDRESS is not set"
  exit 1
else
  echo "MINIO_EXTERNAL_ADDRESS is set to $MINIO_EXTERNAL_ADDRESS"
fi

if [ -z "$MINIO_ADDRESS" ]; then
  echo "MINIO_ADDRESS is not set"
  exit 1
else
  echo "MINIO_ADDRESS is set to $MINIO_ADDRESS"
fi


if [ -z "$INFLUXDB_ADDRESS" ]; then
  echo "INFLUXDB_ADDRESS is not set"
  exit 1
else
  echo "INFLUXDB_ADDRESS is set to $INFLUXDB_ADDRESS"
fi


if [ -z "$REDIS_ADDRESS" ]; then
  echo "REDIS_ADDRESS is not set"
  exit 1
else
  echo "REDIS_ADDRESS is set to $REDIS_ADDRESS"
fi


echo "DATABASE_PREFIX is set to '$DATABASE_PREFIX'"

export HEARTH_DATABASE_URL=$MONGODB_ADMIN_ADDRESS/$DATABASE_PREFIX-hearth?authSource=admin
export OPENHIM_DATABASE_URL=$MONGODB_ADMIN_ADDRESS/$DATABASE_PREFIX-openhim?authSource=admin

# Create new influx database
curl -i -XPOST http://$INFLUXDB_ADDRESS/query --data-urlencode "q=CREATE DATABASE \"$DATABASE_PREFIX-ocrvs\""

# Empty monitoring.ts file
truncate -s 0 /opencrvs-core/packages/commons/src/monitoring.ts

# For proxy to add to client config
export MINIO_BUCKET="$DATABASE_PREFIX-ocrvs"

/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf