docker run \
-p 7000:7000 \
-p 7071:7070 \
-e MONGODB_ADMIN_ADDRESS=mongodb://host.docker.internal:27017 \
-e ELASTICSEARCH_ADMIN_ADDRESS=host.docker.internal:9200 \
-e MINIO_EXTERNAL_ADDRESS=localhost:3535 \
-e MINIO_ADDRESS=host.docker.internal:3535 \
-e INFLUXDB_ADDRESS=host.docker.internal:8086 \
-e REDIS_ADDRESS=host.docker.internal:6379 \
-e DATABASE_PREFIX=$(date +%s) \
-e CORE_VERSION=pr-previews \
-v ./init.sh:/init.sh \
-v ./start.sh:/app/start.sh \
-v ./index.js:/app/index.js \
-v ./start-country-config.sh:/app/start-country-config.sh \
-v ./prefix-output.sh:/app/prefix-output.sh \
-v ./supervisord.conf:/etc/supervisor/conf.d/supervisord.conf \
--rm \
--name opencrvs-standalone \
opencrvs-standalone:latest