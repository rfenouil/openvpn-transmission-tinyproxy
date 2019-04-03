#!/bin/bash

# First script executed on docker start (CMD).
# Create tunnel device, search for '*.ovpn' configuration files in mounted volume, and
# select a random one (or download one from NordVPN website if credentials provided).
# Create a route to local network for accessing transmission from outside docker, then 
# start openVPN with --up and --down scripts to synchronize transmission and tinyproxy 
# execution with status of VPN connection.


# Environment variables
#
# OPENVPN_CONFIGFILE_SELECT_REGEX : If openVPN configuration file is selected from provided local folder, applies selection using provided regular expression before final random selection.
# OPENVPN_OPTS : additional options when starting openvpn client.
# 
# Used by 'NordVPN_getConfig.sh'
# NORDVPN_USERNAME & NORDVPN_PASSWORD : If set, openvpn config file is downloaded from NordVPN website and configured with credentials and default options.
# NORDVPN_CONFIGNAME : Direct selection of an online configuration file by name (e.g. 'it69.nordvpn.com.tcp'). All other NORDVPN_* variables ignored if set.
# NORDVPN_COUNTRY    : Country name or code as defined by NordVPN online API (e.g. 'it', 'fr', 'de', ...). Required for selection of 'recommended' server.
# NORDVPN_TECHNOLOGY : Prefered method of connection for configuration selection. UDP or TCP (default).
# NORDVPN_GROUP      : Prefered type of server (e.g. 'P2P', 'Double VPN', ...). Optional and not guaranteed.
# 
# Used by scripts starting transmission and tinyproxy (see tunnelUp.sh)
# PUID & PGID        : alter container local user uid and gid to fit system users file permissions.
# DROP_DEFAULT_ROUTE : forbids any use of regular connection instead of VPN tunnel in container.
# TRANSMISSION_*     : generate transmission configuration file (json) and start daemon.
# WEBPROXY_*         : customize existing tinyproxy configuration file and start daemon.
# 

echo "OpenVPN start script..."

# If the script is called from elsewhere come back to script directory 
# so we can access other local scripts and downloaded configs directly
cd "${0%/*}"



# If create_tun_device is set, create /dev/net/tun
if [[ "${CREATE_TUN_DEVICE,,}" == "true" ]]; then
  echo "Creating tunnel device..."
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200
  chmod 0666 /dev/net/tun
fi



# If openvpn-pre-start.sh exists, run it
if [[ -x "/scripts/openvpn-pre-start.sh" ]]; then
   echo "Executing /scripts/openvpn-pre-start.sh"
   /scripts/openvpn-pre-start.sh "$@"
   echo "/scripts/openvpn-pre-start.sh returned $?"
fi



# Folder where openVPN configuration files are stored (if any)
OPENVPN_CONFIGFILES_DIR="/ovpnFiles" # Volume mounted by Docker

# If no NordVPN credentials provided, search for existing preconfigured ovpn files in mounted volume
if [[ "${NORDVPN_USERNAME}" == "**None**" ]] || [[ "${NORDVPN_PASSWORD}" == "**None**" ]]; then
    
    echo "Searching OpenVPN configuration files in mounted volume..."
    OPENVPN_CONFIGFILES=($(find ${OPENVPN_CONFIGFILES_DIR} -iname '*.ovpn')) # Get available files as bash array
    
    # Check number of configuration files found
    if [[ ${#OPENVPN_CONFIGFILES[*]} -eq 0 ]]; then
        echo "No OpenVPN configuration file found in mounted volume. Please provide configuration files (or credentials to setup a config from NordVPN server). Exiting."
        exit 1
    fi
    
    echo "Found ${#OPENVPN_CONFIGFILES[*]} files."
    
    # Filter files if 'OPENVPN_CONFIG_SELECT' is not empty
    if [[ -n "${OPENVPN_CONFIGFILE_SELECT_REGEX-}" ]]; then
        echo "Removing config filenames not matching 'OPENVPN_CONFIGFILE_SELECT_REGEX' regex..."
        for index in "${!OPENVPN_CONFIGFILES[@]}" ; do [[ ${OPENVPN_CONFIGFILES[$index]} =~ $OPENVPN_CONFIGFILE_SELECT_REGEX ]] || unset -v 'OPENVPN_CONFIGFILES[$index]' ; done
    fi
    
    # Check number of remaining files after filtering 
    if [[ ${#OPENVPN_CONFIGFILES[*]} -eq 0 ]]; then
        echo "No OpenVPN configuration file remaining after selection. Please check that regular expression matches some filenames in mounted volume. Exiting."
        exit 1
    fi
    
    # Random selection
    echo "Selecting random configuration from ${#OPENVPN_CONFIGFILES[@]} available files..."
    OPENVPN_CONFIG=${OPENVPN_CONFIGFILES[$RANDOM % ${#OPENVPN_CONFIGFILES[@]}]}
    echo "Selected: '${OPENVPN_CONFIG}'"
    
else
    
    echo "Credentials provided, setting credentials file..."
    mkdir -p /config
    echo "${NORDVPN_USERNAME}" > /config/openvpn-credentials.txt
    echo "${NORDVPN_PASSWORD}" >> /config/openvpn-credentials.txt
    chmod 600 /config/openvpn-credentials.txt
     
    echo "Getting recommended server from NordVPN website..."
    export OPENVPN_CONFIG="$(./NordVPN_getConfig.sh).ovpn"
    echo "Downloaded and configured: '${OPENVPN_CONFIG}'"
    
fi



# Create and save a bash script from template (using dockerize) which exports environment variables of interest. To be used in scripts started by openVPN (--up and --down) because it does not copy parent environment for their execution.
dockerize -template /importedScripts/transmission/dockerize_environment_variables_for_export.tmpl:/importedScripts/transmission/dockerize_environment_variables_for_export.sh

# Start openvpn with --up and --down scripts, eventual options added from environment variables, and specify selected config file
TRANSMISSION_CONTROL_OPTS="--script-security 2 --up-delay --up tunnelUp.sh --down tunnelDown.sh"
exec openvpn ${TRANSMISSION_CONTROL_OPTS} ${OPENVPN_OPTS} --config "${OPENVPN_CONFIG}"



