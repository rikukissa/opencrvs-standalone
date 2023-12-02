set -e

export DOMAIN='*'
export LOG_LEVEL="info"

echo "DATABASE_PREFIX is set to '$DATABASE_PREFIX'"


if [ -n "$COUNTRY_CONFIG_GIT_URL" ]; then
  echo "Checking out version $VERSION and reinstalling dependencies"
  rm -rf /country-config
  git clone $COUNTRY_CONFIG_GIT_URL /country-config
fi

if [ -n "$COUNTRY_CONFIG_VERSION" ]; then
  cd /country-config
  echo "Checking out version $COUNTRY_CONFIG_VERSION and reinstalling dependencies"
  git fetch origin $COUNTRY_CONFIG_VERSION:$COUNTRY_CONFIG_VERSION --depth=1
  git checkout $COUNTRY_CONFIG_VERSION
fi

cd /country-config
yarn
yarn start:prod