
export HOST='0.0.0.0'
export HOSTNAME='*'
export NODE_ENV=development
export LOG_LEVEL="error"

export MINIO_URL="$MINIO_EXTERNAL_ADDRESS"
export DISABLE_RATE_LIMIT=false
export OPENHIM_MONGO_URL=$MONGODB_ADDRESS/$DATABASE_PREFIX-openhim

if [ -n "$CORE_VERSION" ]; then
  cd /opencrvs-core
  echo "Checking out version $CORE_VERSION and reinstalling dependencies"
  git checkout $CORE_VERSION
fi

cd /opencrvs-core && yarn && npx lerna run build --stream && yarn dev:secrets:gen

cd /opencrvs-core/packages/migration
yarn start

# Change all hostnames to localhost as we do not use extra hosts in this setup
mongo $OPENHIM_MONGO_URL --eval 'db.channels.updateMany({"routes.host": {$exists: true}}, {$set: {"routes.$[].host": "localhost"}})'

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