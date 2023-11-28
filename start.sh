if [ -n "$CORE_VERSION" ]; then
  cd /opencrvs-core
  echo "Checking out version $CORE_VERSION and reinstalling dependencies"
  git checkout $CORE_VERSION
  yarn
  npx lerna run build --stream --concurrency=1
fi

export COUNTRY_CONFIG_URL=${COUNTRY_CONFIG_URL:-'http://localhost:3040'}
export COUNTRY_CONFIG_HOST=${COUNTRY_CONFIG_HOST:-'http://localhost:3040'}
if [ -n "$COUNTRY_CONFIG_GIT_URL" ]; then
  echo "Checking out version $VERSION and reinstalling dependencies"
  rm -rf /country-config
  git clone $COUNTRY_CONFIG_GIT_URL /country-config
  cd /country-config
  yarn
  yarn build
  yarn start:prod &
fi

if [ -n "$COUNTRY_CONFIG_VERSION" ]; then
  cd /country-config
  echo "Checking out version $COUNTRY_CONFIG_VERSION and reinstalling dependencies"
  git checkout $CORE_VERSION
  yarn
  yarn build
fi

cd /opencrvs-core

npx wait-on -l tcp:3535
npx wait-on -l tcp:5001
npx wait-on -l tcp:9200
curl -i -XPOST http://localhost:8086/query --data-urlencode "q=CREATE DATABASE ocrvs"

export HOST='0.0.0.0'
export HOSTNAME='*'
export NODE_ENV=development
export EXPOSED_PORT=${EXPOSED_PORT:-7000}
export MINIO_URL="localhost:$EXPOSED_PORT"
export DISABLE_RATE_LIMIT=false
export OPENHIM_MONGO_URL=mongodb://localhost/openhim
export LOG_LEVEL="error"

cd /opencrvs-core/packages/migration
yarn start

# Change all hostnames to localhost as we do not use extra hosts in this setup
mongo openhim --eval 'db.channels.updateMany({"routes.host": {$exists: true}}, {$set: {"routes.$[].host": "localhost"}})'

cd /opencrvs-core
npx lerna run --parallel \
--ignore @opencrvs/components \
--ignore @opencrvs/migration \
--ignore @opencrvs/dashboards \
--ignore @opencrvs/mobile-proxy \
start:prod &

LERNA_PID=$!

npx wait-on -l tcp:2021
npx wait-on -l tcp:4040
npx wait-on -l tcp:5001
npx wait-on -l tcp:3447

cd /opencrvs-core

yarn seed:dev

wait $LERNA_PID

tail -f /dev/null