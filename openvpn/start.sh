#!/bin/bash


# Folder where openVPN configuration files are stored (if any)
OPENVPN_CONFIGFILES_DIR="/ovpnFiles" # Volume mounted by DockerFile


echo "OpenVPN start script..."

# If create_tun_device is set, create /dev/net/tun
if [[ "${CREATE_TUN_DEVICE,,}" == "true" ]]; then
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200
  chmod 0666 /dev/net/tun
fi


# If openvpn-pre-start.sh exists, run it
if [ -x /scripts/openvpn-pre-start.sh ]
then
   echo "Executing /scripts/openvpn-pre-start.sh"
   /scripts/openvpn-pre-start.sh "$@"
   echo "/scripts/openvpn-pre-start.sh returned $?"
fi



if [[ "${OPENVPN_USERNAME}" == "**None**" ]] || [[ "${OPENVPN_PASSWORD}" == "**None**" ]] ; then
    
    echo "Searching OpenVPN configuration files in mounted volume..."
    OPENVPN_CONFIGFILES=($(find ${OPENVPN_CONFIGFILES_DIR} -iname '*.ovpn')) # Get available files as bash array
    
    # Check number of configuration files found
    if [[ ${#OPENVPN_CONFIGFILES[*]} -eq 0 ]] then
        echo "No OpenVPN configuration file found in mounted volume. Please provide configuration files (or credentials to setup a config from NordVPN server). Exiting."
        exit 1
    fi
    
    echo "Found ${#OPENVPN_CONFIGFILES[*]} files."
    
    # Filter files if 'OPENVPN_CONFIG_SELECT' is not empty
    if [[ -n ${OPENVPN_CONFIG_SELECT-} ]] then
        echo "Removing config filenames not matching 'OPENVPN_CONFIG_SELECT' regex..."
        for index in "${!OPENVPN_CONFIGFILES[@]}" ; do [[ ${OPENVPN_CONFIGFILES[$index]} =~ $OPENVPN_CONFIG_SELECT ]] || unset -v 'OPENVPN_CONFIGFILES[$index]' ; done
    fi
    
    # Check number of remaining files after filtering 
    if [[ ${#OPENVPN_CONFIGFILES[*]} -eq 0 ]] then
        echo "No OpenVPN configuration file remaining after selection. Please check that regular expression matches some filenames in mounted volume. Exiting."
        exit 1
    fi
    
    # Random selection
    echo "Selecting random configuration from ${#OPENVPN_CONFIGFILES[@]} available files..."
    OPENVPN_CONFIG=${OPENVPN_CONFIGFILES[$RANDOM % ${#OPENVPN_CONFIGFILES[@]} ]}
    echo "Selected: ${OPENVPN_CONFIG}."
    
else
    
    echo "Credentials provided, setting OPENVPN credentials..."
    mkdir -p /config
    echo "${OPENVPN_USERNAME}" > /config/openvpn-credentials.txt
    echo "${OPENVPN_PASSWORD}" >> /config/openvpn-credentials.txt
    chmod 600 /config/openvpn-credentials.txt
     
    echo "Getting recommended server from NordVPN website..."
    export OPENVPN_CONFIG="$(NordVPN_getConfig.sh).ovpn"
    echo "Downloaded and configured: ${OPENVPN_CONFIG}."
    
fi



# Persist transmission settings for use by transmission-daemon
dockerize -template /etc/transmission/environment-variables.tmpl:/etc/transmission/environment-variables.sh

TRANSMISSION_CONTROL_OPTS="--script-security 2 --up-delay --up /etc/openvpn/tunnelUp.sh --down /etc/openvpn/tunnelDown.sh"



# Grab network config info (INT & GW)
if [[ -n "${LOCAL_NETWORK-}" ]]; then
  eval $(/sbin/ip r l m 0.0.0.0 | awk '{if($5!="tun0"){print "GW="$3"\nINT="$5; exit}}')
fi

# Add route to local network
if [[ -n "${LOCAL_NETWORK-}" ]]; then
  if [[ -n "${GW-}" ]] && [[ -n "${INT-}" ]]; then
    for localNet in ${LOCAL_NETWORK//,/ }; do
      echo "adding route to local network ${localNet} via ${GW} dev ${INT}"
      /sbin/ip r a "${localNet}" via "${GW}" dev "${INT}"
    done
  fi
fi



# Start openvpn
exec openvpn ${TRANSMISSION_CONTROL_OPTS} ${OPENVPN_OPTS} --config "${OPENVPN_CONFIG}"



