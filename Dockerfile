FROM debian
MAINTAINER rfenouil

VOLUME /data
VOLUME /ovpnFiles

#### Update packages and install main software
RUN apt-get update \
    &&  apt-get -y install curl \
                           dumb-init \
                           git \
                           jq \
                           openvpn \
                           tinyproxy \
                           transmission-cli \
                           transmission-common \
                           transmission-daemon \
                           unzip



#### User interfaces for transmission
# combustion
RUN curl -L -o /tmp/release.zip https://github.com/Secretmapper/combustion/archive/release.zip \
    && unzip /tmp/release.zip -d /opt/transmission-ui/ \
    && rm /tmp/release.zip

# kettu
RUN git clone git://github.com/endor/kettu.git /opt/transmission-ui/kettu

# transmission-web-control
RUN mkdir /opt/transmission-ui/transmission-web-control \
    && curl -L `curl -s https://api.github.com/repos/ronggang/transmission-web-control/releases/latest | jq --raw-output '.tarball_url'` | tar -C /opt/transmission-ui/transmission-web-control/ --strip-components=2 -xzv \
    && ln -s /usr/share/transmission/web/style /opt/transmission-ui/transmission-web-control \
    && ln -s /usr/share/transmission/web/images /opt/transmission-ui/transmission-web-control \
    && ln -s /usr/share/transmission/web/javascript /opt/transmission-ui/transmission-web-control \
    && ln -s /usr/share/transmission/web/index.html /opt/transmission-ui/transmission-web-control/index.original.html



#### Dockerize (logs, configurations, environment variables)
RUN curl -L https://github.com/jwilder/dockerize/releases/download/v0.6.0/dockerize-linux-armhf-v0.6.0.tar.gz | tar -C /usr/local/bin -xzv



#### Create a local user in container 
# Used to start transmission after altering its uid (to specified system user uid) for file permissions
RUN groupmod -g 1000 users \
    && useradd -u 911 -U -d /config -s /bin/false tempContainerUser \
    && usermod -G users tempContainerUser



#### Add configuration and scripts
ADD openvpn/      /importedScripts/openvpn/
ADD transmission/ /importedScripts/transmission/
ADD tinyproxy/    /importedScripts/tinyproxy/



#### Define environment variables used for configuration
ENV NORDVPN_USERNAME=**None** \
    NORDVPN_PASSWORD=**None** \
    \
    NORDVPN_CONFIGNAME= \
    NORDVPN_COUNTRY=It \
    NORDVPN_TECHNOLOGY=tcp \
    NORDVPN_GROUP=P2P \
    \
    OPENVPN_CONFIGFILE_SELECT_REGEX= \
    OPENVPN_OPTS="--ping 10 --ping-exit 60" \
    \
    PUID=1000\
    PGID=100\
    \
    LOCAL_NETWORK=192.168.0.0/16 \
    DROP_DEFAULT_ROUTE=true \
    \
    TRANSMISSION_HOME=/data/transmission-home \
    TRANSMISSION_DOWNLOAD_DIR=/complete \
    TRANSMISSION_INCOMPLETE_DIR=/data/incomplete \
    TRANSMISSION_WATCH_DIR=/data/watch \
    \
    TRANSMISSION_ALT_SPEED_DOWN=50 \
    TRANSMISSION_ALT_SPEED_ENABLED=false \
    TRANSMISSION_ALT_SPEED_TIME_BEGIN=540 \
    TRANSMISSION_ALT_SPEED_TIME_DAY=127 \
    TRANSMISSION_ALT_SPEED_TIME_ENABLED=false \
    TRANSMISSION_ALT_SPEED_TIME_END=1020 \
    TRANSMISSION_ALT_SPEED_UP=50 \
    TRANSMISSION_BIND_ADDRESS_IPV4=0.0.0.0 \
    TRANSMISSION_BIND_ADDRESS_IPV6=:: \
    TRANSMISSION_BLOCKLIST_ENABLED=false \
    TRANSMISSION_BLOCKLIST_URL=http://www.example.com/blocklist \
    TRANSMISSION_CACHE_SIZE_MB=80 \
    TRANSMISSION_DHT_ENABLED=false \
    TRANSMISSION_DOWNLOAD_LIMIT=100 \
    TRANSMISSION_DOWNLOAD_LIMIT_ENABLED=0 \
    TRANSMISSION_DOWNLOAD_QUEUE_ENABLED=true \
    TRANSMISSION_DOWNLOAD_QUEUE_SIZE=5 \
    TRANSMISSION_ENCRYPTION=1 \
    TRANSMISSION_IDLE_SEEDING_LIMIT=30 \
    TRANSMISSION_IDLE_SEEDING_LIMIT_ENABLED=false \
    TRANSMISSION_INCOMPLETE_DIR_ENABLED=true \
    TRANSMISSION_LPD_ENABLED=false \
    TRANSMISSION_MAX_PEERS_GLOBAL=500 \
    TRANSMISSION_MESSAGE_LEVEL=2 \
    TRANSMISSION_PEER_CONGESTION_ALGORITHM= \
    TRANSMISSION_PEER_ID_TTL_HOURS=6 \
    TRANSMISSION_PEER_LIMIT_GLOBAL=500 \
    TRANSMISSION_PEER_LIMIT_PER_TORRENT=100 \
    TRANSMISSION_PEER_PORT=51413 \
    TRANSMISSION_PEER_PORT_RANDOM_HIGH=65535 \
    TRANSMISSION_PEER_PORT_RANDOM_LOW=49152 \
    TRANSMISSION_PEER_PORT_RANDOM_ON_START=false \
    TRANSMISSION_PEER_SOCKET_TOS=default \
    TRANSMISSION_PEX_ENABLED=false \
    TRANSMISSION_PORT_FORWARDING_ENABLED=false \
    TRANSMISSION_PREALLOCATION=1 \
    TRANSMISSION_PREFETCH_ENABLED=1 \
    TRANSMISSION_QUEUE_STALLED_ENABLED=true \
    TRANSMISSION_QUEUE_STALLED_MINUTES=30 \
    TRANSMISSION_RATIO_LIMIT=2 \
    TRANSMISSION_RATIO_LIMIT_ENABLED=false \
    TRANSMISSION_RENAME_PARTIAL_FILES=true \
    TRANSMISSION_RPC_AUTHENTICATION_REQUIRED=false \
    TRANSMISSION_RPC_BIND_ADDRESS=0.0.0.0 \
    TRANSMISSION_RPC_ENABLED=true \
    TRANSMISSION_RPC_HOST_WHITELIST= \
    TRANSMISSION_RPC_HOST_WHITELIST_ENABLED=false \
    TRANSMISSION_RPC_PASSWORD=password \
    TRANSMISSION_RPC_PORT=9091 \
    TRANSMISSION_RPC_URL=/transmission/ \
    TRANSMISSION_RPC_USERNAME=username \
    TRANSMISSION_RPC_WHITELIST=127.0.0.1 \
    TRANSMISSION_RPC_WHITELIST_ENABLED=false \
    TRANSMISSION_SCRAPE_PAUSED_TORRENTS_ENABLED=true \
    TRANSMISSION_SCRIPT_TORRENT_DONE_ENABLED=false \
    TRANSMISSION_SCRIPT_TORRENT_DONE_FILENAME= \
    TRANSMISSION_SEED_QUEUE_ENABLED=false \
    TRANSMISSION_SEED_QUEUE_SIZE=10 \
    TRANSMISSION_SPEED_LIMIT_DOWN=100 \
    TRANSMISSION_SPEED_LIMIT_DOWN_ENABLED=false \
    TRANSMISSION_SPEED_LIMIT_UP=100 \
    TRANSMISSION_SPEED_LIMIT_UP_ENABLED=false \
    TRANSMISSION_START_ADDED_TORRENTS=true \
    TRANSMISSION_TRASH_ORIGINAL_TORRENT_FILES=false \
    TRANSMISSION_UMASK=2 \
    TRANSMISSION_UPLOAD_LIMIT=100 \
    TRANSMISSION_UPLOAD_LIMIT_ENABLED=0 \
    TRANSMISSION_UPLOAD_SLOTS_PER_TORRENT=14 \
    TRANSMISSION_UTP_ENABLED=false \
    TRANSMISSION_WATCH_DIR_ENABLED=true \
    TRANSMISSION_WATCH_DIR_FORCE_GENERIC=false \
    TRANSMISSION_WEB_HOME= \
    TRANSMISSION_WEB_UI=transmission-web-control \
    \
    WEBPROXY_ENABLED=true \
    WEBPROXY_PORT=8888
    


#### Expose ports (transmission and proxy)
EXPOSE 9091
EXPOSE 8888



#### Run 'start_openVPN.sh' script that starts everything
CMD ["dumb-init", "/importedScripts/openvpn/start_openVPN.sh"]


