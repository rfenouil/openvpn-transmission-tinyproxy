#!/bin/sh

# More/less taken from https://github.com/linuxserver/docker-baseimage-alpine/blob/3eb7146a55b7bff547905e0d3f71a26036448ae6/root/etc/cont-init.d/10-adduser
# Alter the uid of local user 'tempContainerUser' (created during container setup) to specified one (preferably from existing user in actual system). This will ensure compatible user file permissions inside and outside container.

RUN_AS=root

if [[ -n "$PUID" ]] && [[ ! "$(id -u root)" -eq "$PUID" ]]; then
    RUN_AS=tempContainerUser
    if [ ! "$(id -u ${RUN_AS})" -eq "$PUID" ]; then usermod -o -u "$PUID" ${RUN_AS} ; fi
    if [ ! "$(id -g ${RUN_AS})" -eq "$PGID" ]; then groupmod -o -g "$PGID" ${RUN_AS} ; fi

    # Make sure directories exist before chown and chmod
    mkdir -p /config \
        ${TRANSMISSION_HOME} \
        ${TRANSMISSION_DOWNLOAD_DIR} \
        ${TRANSMISSION_INCOMPLETE_DIR} \
        ${TRANSMISSION_WATCH_DIR}

    echo "Enforcing ownership on transmission directories"
    chown -R ${RUN_AS}:${RUN_AS} \
        /config \
        ${TRANSMISSION_HOME} \
        ${TRANSMISSION_DOWNLOAD_DIR} \
        ${TRANSMISSION_INCOMPLETE_DIR} \
        ${TRANSMISSION_WATCH_DIR}

    echo "Applying permissions to transmission directories"
    chmod -R go=rX,u=rwX \
        /config \
        ${TRANSMISSION_HOME} \
        ${TRANSMISSION_DOWNLOAD_DIR} \
        ${TRANSMISSION_INCOMPLETE_DIR} \
        ${TRANSMISSION_WATCH_DIR}

fi

echo "
-------------------------------------
Transmission will run as
-------------------------------------
User name:   ${RUN_AS}
User uid:    $(id -u ${RUN_AS})
User gid:    $(id -g ${RUN_AS})
-------------------------------------
"

export PUID
export PGID
export RUN_AS
