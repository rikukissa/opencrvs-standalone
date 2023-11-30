
export HOST='0.0.0.0'
export NODE_ENV=development
export LOG_LEVEL="info"
export LANGUAGES="en,fr"
export MINIO_URL="$MINIO_EXTERNAL_ADDRESS"
export DISABLE_RATE_LIMIT=false
export OPENHIM_MONGO_URL=$MONGODB_ADDRESS/$DATABASE_PREFIX-openhim

if [ -n "$CORE_VERSION" ]; then
  cd /opencrvs-core
  echo "Checking out version $CORE_VERSION and reinstalling dependencies"
  git fetch origin $CORE_VERSION:$CORE_VERSION
  git checkout $CORE_VERSION
fi

cd /opencrvs-core && yarn && npx lerna run build --stream && yarn dev:secrets:gen


export HEARTH_MONGO_URL=$MONGODB_ADDRESS/$DATABASE_PREFIX-hearth?authSource=admin
export APPLICATION_CONFIG_MONGO_URL=$MONGODB_ADDRESS/$DATABASE_PREFIX-application-config?authSource=admin
export OPENHIM_MONGO_URL=$MONGODB_ADDRESS/$DATABASE_PREFIX-openhim?authSource=admin
export PERFORMANCE_MONGO_URL=$MONGODB_ADDRESS/$DATABASE_PREFIX-performance?authSource=admin
export USER_MGNT_MONGO_URL=$MONGODB_ADDRESS/$DATABASE_PREFIX-user-mgnt?authSource=admin
export METRICS_MONGO_URL=$MONGODB_ADDRESS/$DATABASE_PREFIX-metrics?authSource=admin
export WEBHOOKS_MONGO_URL=$MONGODB_ADDRESS/$DATABASE_PREFIX-webhooks?authSource=admin

export INFLUX_HOST=${INFLUXDB_ADDRESS%:*}
export INFLUX_PORT=${INFLUXDB_ADDRESS#*:}
export INFLUX_DB="$DATABASE_PREFIX-ocrvs"
export REDIS_HOST=${REDIS_ADDRESS%:*}
export MINIO_HOST=${MINIO_ADDRESS%:*}
export MINIO_PORT=${MINIO_ADDRESS#*:}
export MINIO_URL=$MINIO_URL
export MINIO_BUCKET="$DATABASE_PREFIX-ocrvs"

export ELASTICSEARCH_INDEX_NAME="$DATABASE_PREFIX-ocrvs"
export ES_HOST=$ELASTICSEARCH_ADDRESS

cd /opencrvs-core/packages/migration
yarn start

# Change all hostnames to localhost as we do not use extra hosts in this setup
node -e "require('mongodb').MongoClient.connect(process.env.OPENHIM_MONGO_URL, { useNewUrlParser: true, useUnifiedTopology: true }).then(client => client.db().collection('channels').updateMany({ 'routes.host': { \$exists: true } }, { \$set: { 'routes.$[].host': 'localhost' } }).then(result => { console.log('Updated ' + result.modifiedCount + ' documents'); client.close(); })).catch(err => console.error(err));"

cd /opencrvs-core

(npx lerna run --parallel \
--ignore @opencrvs/components \
--ignore @opencrvs/migration \
--ignore @opencrvs/dashboards \
--ignore @opencrvs/mobile-proxy \
--ignore @opencrvs/config \
--ignore @opencrvs/metrics \
--ignore @opencrvs/user-mgnt \
--ignore @opencrvs/webhooks \
--ignore @opencrvs/search \
start:prod > /proc/$$/fd/1 2>&1) &

(MONGO_URL=$APPLICATION_CONFIG_MONGO_URL \
npx lerna run --stream --scope @opencrvs/config start:prod > /proc/$$/fd/1 2>&1) &

(HEARTH_MONGO_URL=$HEARTH_MONGO_URL \
MONGO_URL=$METRICS_MONGO_URL \
npx lerna run --stream --scope @opencrvs/metrics start:prod > /proc/$$/fd/1 2>&1) &

(MONGO_URL=$USER_MGNT_MONGO_URL \
npx lerna run --stream --scope @opencrvs/user-mgnt start:prod > /proc/$$/fd/1 2>&1) &

(MONGO_URL=$WEBHOOKS_MONGO_URL \
npx lerna run --stream --scope @opencrvs/webhooks start:prod > /proc/$$/fd/1 2>&1) &

(HEARTH_MONGO_URL=$HEARTH_MONGO_URL \
ES_HOST=$ELASTICSEARCH_ADDRESS \
OPENCRVS_INDEX_NAME="$DATABASE_PREFIX-ocrvs" \
MONGO_URL=$SEARCH_MONGO_URL npx lerna run --stream --scope @opencrvs/search start:prod > /proc/$$/fd/1 2>&1) &

cd /opencrvs-core

npx wait-on -l tcp:5001
npx wait-on -l tcp:3447
npx wait-on -l tcp:7070

# Run yarn seed:dev until it succeeds
while ! yarn seed:dev; do
  echo "Retrying yarn seed:dev..."
done

tail -f /dev/null