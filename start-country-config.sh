set -e

export DOMAIN='*'

echo "DATABASE_PREFIX is set to '$DATABASE_PREFIX'"

export HEARTH_URL=$MONGODB_ADDRESS/$DATABASE_PREFIX-hearth
export OPENHIM_URL=$MONGODB_ADDRESS/$DATABASE_PREFIX-openhim
export DOMAIN='*'


# export COUNTRY_CONFIG_URL=${COUNTRY_CONFIG_URL:-'http://localhost:3040'}
# export COUNTRY_CONFIG_HOST=${COUNTRY_CONFIG_HOST:-'http://localhost:3040'}

if [ -n "$COUNTRY_CONFIG_GIT_URL" ]; then
  echo "Checking out version $VERSION and reinstalling dependencies"
  rm -rf /country-config
  git clone $COUNTRY_CONFIG_GIT_URL /country-config
fi

if [ -n "$COUNTRY_CONFIG_VERSION" ]; then
  cd /country-config
  echo "Checking out version $COUNTRY_CONFIG_VERSION and reinstalling dependencies"
  git checkout $CORE_VERSION
fi

cd /country-config
yarn
yarn start:prod