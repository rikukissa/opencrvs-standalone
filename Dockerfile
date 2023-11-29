FROM node:16.20.2-bullseye

ARG DEBIAN_FRONTEND=noninteractive

# Install utilities
RUN apt update && apt install -y supervisor

RUN apt-get install -y supervisor

# Copy your Node.js application
COPY . /app
COPY ./init.sh /init.sh

# Copy configuration files for each service and scripts to start them
# You need to create these configuration files and scripts
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN apt-get install -y git
RUN git clone --depth=1 -b develop https://github.com/opencrvs/opencrvs-core.git /opencrvs-core
RUN git clone --depth=1 https://github.com/jembi/hearth.git /hearth
RUN git clone --depth=1 https://github.com/jembi/openhim-core-js.git /openhim
RUN git clone --depth=1 https://github.com/opencrvs/opencrvs-farajaland.git /country-config

# This is a little risky optimisation
RUN cd /opencrvs-core && yarn
RUN cd /country-config && yarn

RUN cd /hearth && npm install
RUN cd /openhim && npm install && npm run build

EXPOSE 7000

# Start all services using supervisord
CMD ["/init.sh"]


