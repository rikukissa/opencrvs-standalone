# Use an official Ubuntu as a parent image
FROM ubuntu:20.04
ENV TZ=Europe/Helsinki
ARG DEBIAN_FRONTEND=noninteractive

# Install utilities
RUN apt-get update && apt-get install -y gnupg wget libssl-dev libssl1.1 build-essential

RUN mkdir /data
RUN mkdir /data/mongo
RUN mkdir /data/minio
RUN mkdir /data/elasticsearch
RUN mkdir /data/influxdb

# Install MongoDB
ENV TZ=Europe/Helsinki
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
RUN echo "deb http://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list
RUN apt-get update && apt-get install --force-yes -y mongodb-org

# Install Elasticsearch 7.17
RUN useradd -ms /bin/bash elasticsearch
RUN wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add - && \
  echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-7.x.list && \
  apt-get update && \
  apt-get install -y elasticsearch=7.17.0
RUN chown elasticsearch:elasticsearch -R /usr/share/elasticsearch

# Install InfluxDB 1.8.0

USER root
RUN if [ "$(uname -m)" = "x86_64" ]; then \
    wget https://dl.influxdata.com/influxdb/releases/influxdb_1.8.0_amd64.deb && \
    dpkg -i influxdb_1.8.0_amd64.deb; \
  else \
    wget https://dl.influxdata.com/influxdb/releases/influxdb_1.8.0_arm64.deb && \
    dpkg -i influxdb_1.8.0_arm64.deb; \
  fi

# Download MinIO binary
RUN wget https://dl.min.io/server/minio/release/linux-amd64/minio -O /usr/local/bin/minio
RUN chmod +x /usr/local/bin/minio

# Set up MinIO environment variables
ENV MINIO_ACCESS_KEY=minioadmin
ENV MINIO_SECRET_KEY=minioadmin
ENV MINIO_ROOT_USER=minioadmin
ENV MINIO_ROOT_PASSWORD=minioadmin

# Install Redis 5
RUN apt-get install -y redis-server

# Install Node.js
RUN apt-get install -y curl
ENV NODE_VERSION=16.20.0
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
ENV NVM_DIR=/root/.nvm
RUN . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION}
ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin/:${PATH}"
RUN node --version
RUN npm --version

RUN apt-get install -y supervisor

# Copy your Node.js application
COPY . /app

# Copy configuration files for each service and scripts to start them
# You need to create these configuration files and scripts
COPY redis.conf /etc/redis/redis.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN apt-get install -y git
RUN git clone --depth=1 -b develop https://github.com/opencrvs/opencrvs-core.git /opencrvs-core
RUN git clone --depth=1 https://github.com/jembi/hearth.git /hearth
RUN git clone --depth=1 https://github.com/jembi/openhim-core-js.git /openhim
RUN git clone --depth=1 https://github.com/opencrvs/opencrvs-farajaland.git /country-config

RUN npm install -g yarn serve wait-on

RUN cd /app
RUN cd /opencrvs-core && yarn && yarn build && yarn dev:secrets:gen
RUN cd /hearth && npm install
RUN cd /openhim && npm install && npm run build
RUN cd /country-config && yarn

EXPOSE 7000

ENV EXPOSED_PORT=7000

# Start all services using supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

