#!/bin/bash

# Starting transmission !
# Create json configuration file for transmission from relevant environment variables and start transmission daemon.

# This script is called by openVPN when tunnel gets connected (tunnelUp.sh), but environment variables defined in parent shell are not copied.
# The following script has been made during startup in parent shell (dockerize) to get appropriate variables defined in subshells (started by openVPN).  
. /importedScripts/transmission/dockerize_environment_variables_for_export.sh



# OpenVPN defines tun/tap device name as parameter 1, and local IP as parameter 4
echo "Up script executed with $*"
if [[ "$4" = "" ]]; then
   echo "ERROR, unable to obtain tunnel address"
   echo "killing $PPID"
   kill -9 $PPID
   exit 1
fi



# If transmission-pre-start.sh exists, run it
if [[ -x /scripts/transmission-pre-start.sh ]]
then
   echo "Executing /scripts/transmission-pre-start.sh"
   /scripts/transmission-pre-start.sh "$@"
   echo "/scripts/transmission-pre-start.sh returned $?"
fi



echo "Updating TRANSMISSION_BIND_ADDRESS_IPV4 to the ip of $1 : $4"
export TRANSMISSION_BIND_ADDRESS_IPV4=$4



if [[ "combustion" = "$TRANSMISSION_WEB_UI" ]]; then
  echo "Using Combustion UI, overriding TRANSMISSION_WEB_HOME"
  export TRANSMISSION_WEB_HOME=/opt/transmission-ui/combustion-release
fi

if [[ "kettu" = "$TRANSMISSION_WEB_UI" ]]; then
  echo "Using Kettu UI, overriding TRANSMISSION_WEB_HOME"
  export TRANSMISSION_WEB_HOME=/opt/transmission-ui/kettu
fi

if [[ "transmission-web-control" = "$TRANSMISSION_WEB_UI" ]]; then
  echo "Using Transmission Web Control  UI, overriding TRANSMISSION_WEB_HOME"
  export TRANSMISSION_WEB_HOME=/opt/transmission-ui/transmission-web-control
fi



echo "Generating transmission settings.json from environment variables"
# Ensure TRANSMISSION_HOME is created
mkdir -p ${TRANSMISSION_HOME}
dockerize -template /importedScripts/transmission/dockerize_transmission_settings_for_json.tmpl:${TRANSMISSION_HOME}/settings.json

echo "Replacing 'True' by 'true' in generated config file"
sed -i 's/True/true/g' ${TRANSMISSION_HOME}/settings.json

if [[ ! -e "/dev/random" ]]; then
  # Avoid "Fatal: no entropy gathering module detected" error
  echo "INFO: /dev/random not found - symlink to /dev/urandom"
  ln -s /dev/urandom /dev/random
fi



# Eventually create a dummy user with UID specified in environment variable tu run transmission (files permissions)
. /importedScripts/transmission/userSetup.sh # Exports username (root or created user) in ${RUN_AS} variable



if [[ "true" = "$DROP_DEFAULT_ROUTE" ]]; then
  echo "DROPPING DEFAULT ROUTE"
  ip r del default || exit 1
fi



echo "STARTING TRANSMISSION"
exec su --preserve-environment ${RUN_AS} -s /bin/bash -c "/usr/bin/transmission-daemon -g ${TRANSMISSION_HOME} --logfile ${TRANSMISSION_HOME}/transmission.log" &



# If transmission-post-start.sh exists, run it
if [[ -x /scripts/transmission-post-start.sh ]]
then
   echo "Executing /scripts/transmission-post-start.sh"
   /scripts/transmission-post-start.sh "$@"
   echo "/scripts/transmission-post-start.sh returned $?"
fi



echo "Transmission startup script complete."
