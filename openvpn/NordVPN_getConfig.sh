#!/bin/bash



######## Helpers

set -e
TIME_FORMAT=`date "+%Y-%m-%d %H:%M:%S"`

log()  {
    printf "${TIME_FORMAT} %b\n" "$*" > /dev/stderr;
}

fatal_error() {
    printf  "${TIME_FORMAT} ERROR: %b\n" "$*" >&2;
    exit 1
}

# check for utils
script_needs() {
    command -v $1 >/dev/null 2>&1 || fatal_error "This script requires $1 but it's not installed. Please install it and run again. Exiting."
}

script_init() {
    log "Checking curl installation"
    script_needs curl
}



######## Filters
# These three functions check that specified values for 'country', 'group', and 'technology' actually exist on servers,
# and build filters as URL arguments to be used with online recommendation algorithm   

# NORDVPN_COUNTRY="fr" (fr, it, de, us, uk, ...)
# Available values: curl -s "https://api.nordvpn.com/v1/servers/countries" | jq --raw-output '.[] | [.code, .name] | @tsv'
country_filter() { 
    local nordvpn_api=$1
    if [[ -n $NORDVPN_COUNTRY ]]; then
        # Retrieve ID from name or code (case insensitive) if it exists
        local country_id=`curl -s "${nordvpn_api}/v1/servers/countries" | jq --raw-output ".[] |
                          select( (.name|test(\"^${NORDVPN_COUNTRY}$\";\"i\")) or
                                  (.code|test(\"^${NORDVPN_COUNTRY}$\";\"i\")) ) |
                          .id" | head -n 1`
        if [[ -n ${country_id} ]]; then
            log "Creating filter for country: ${NORDVPN_COUNTRY} (id=${country_id})"
            echo "filters\[country_id\]=${country_id}&"
        else
            fatal_error  "Country '$NORDVPN_COUNTRY' not found but a valid value is required for recommendation algorithm. Exiting."
        fi
    fi
}

# NORDVPN_GROUP="P2P" ("Double VPN", "Onion Over VPN", "Ultra fast TV", "Anti DDoS", "Dedicated IP", "Standard VPN servers", "Netflix USA", "P2P", "Obfuscated Servers", "Europe", "The Americas", "Asia Pacific", "Africa, the Middle East and India")
# Available values: curl -s "https://api.nordvpn.com/v1/servers/groups" | jq --raw-output '.[] | [.identifier, .title] | @tsv'
group_filter() {
    local nordvpn_api=$1
    if [[ -n $NORDVPN_GROUP ]]; then
        # Retrieve identifier (not id) from title or identifier (case insensitive) if it exists
        local group_identifier=`curl -s "${nordvpn_api}/v1/servers/groups" | jq --raw-output ".[] |
                                select( (.title      | test(\"${NORDVPN_GROUP}\";\"i\")) or
                                        (.identifier | test(\"${NORDVPN_GROUP}\";\"i\")) ) |
                                .identifier" | head -n 1`
        if [[ -n ${group_identifier} ]]; then
            log "Creating filter for group: ${NORDVPN_GROUP} (identifier=${group_identifier})"
            echo "filters\[servers_groups\]\[identifier\]=${group_identifier}&"
        else
            log "Group '$NORDVPN_GROUP' not found, filter ignored..."
        fi
    fi
}

# NORDVPN_TECHNOLOGY=tcp (udp, tcp)
# Available values: curl -s "https://api.nordvpn.com/v1/technologies" | jq --raw-output '.[] | [.identifier, .name ] | @tsv' | grep openvpn
# In current script only 'udp' and 'tcp' allowed, could be modified using same template as for 'country' and 'group'.
technology_filter() {
    local technology_identifier="openvpn_${NORDVPN_TECHNOLOGY,,}"
    log "Creating filter for technology: ${NORDVPN_TECHNOLOGY,,} (identifier=${technology_identifier})"
    echo "filters\[servers_technologies\]\[identifier\]=${technology_identifier}&"
}



######## Hostname recommendation
# Generate a complete URL (with filters) to query the server recommendation page and use it to retrieve the 'best' server name
 
select_hostname() {
    local nordvpn_api="https://api.nordvpn.com" \
          hostname

    log "Selecting best server using NordVPN API..."
    
    # Generate URL strings for filters  
    filterCountry="$(country_filter ${nordvpn_api})"        # filterCountry is required for recommendation algorithm to work (exits with error if country does not exist in DB)
    filterGroup="$(group_filter ${nordvpn_api})"            # filterGroup get a value only if corresponding environment variable is set (NORDVPN_GROUP) and value exists in DB
    filterTechnology="$(technology_filter ${nordvpn_api})"  # filterTechnology values restricted to openvpn_tcp and openvpn_udp
    
    # Get the recommended server hostname from API using all filters
    # IMPORTANT NOTE: if no country filter specified, the server seems to ignore all other filters and returns a default recommended one based on IP location only (i.e. NOT WHAT WE WANT !)
    hostname=`curl -s "${nordvpn_api}/v1/servers/recommendations?${filterCountry}${filterGroup}${filterTechnology}limit=1" | jq --raw-output ".[].hostname"`
    
    # Try to relax constraints if no server could be found while 'group' filter was defined 
    if [[ -z $hostname ]] && [[ -n $filterGroup ]]; then
        log "Unable to find a server with all specified parameters, trying again with 'country' and 'technology' only..."
        hostname=`curl -s "${nordvpn_api}/v1/servers/recommendations?${filterCountry}${filterTechnology}limit=1" | jq --raw-output ".[].hostname"`
    fi
    
    # The following block is commented because it should be avoided. When no country is specified, other filters are ignored and there is no guarantee that we get openvpn_tcp or openvpn_udp service available
    #if [[ -z ${hostname} ]]; then
    #    log "Unable to find a server with specified parameters, using any recommended server"
    #    hostname="$(curl -s "${nordvpn_api}/v1/servers/recommendations?limit=1" | jq --raw-output ".[].hostname").${NORDVPN_TECHNOLOGY,,}"
    #fi
    
    if [[ -z ${hostname} ]]; then
        fatal_error "Attempt to find a recommended server failed... Exiting."
    fi
    
    log "Recommended server : ${hostname}"
    echo ${hostname}
}



######## Download OpenVPN configuration file from server

download_hostname() {
    # "https://downloads.nordcdn.com/configs/files/ovpn_udp/servers/us3373.nordvpn.com.udp.ovpn"
    local nordvpn_cdn="https://downloads.nordcdn.com/configs/files/ovpn_${NORDVPN_TECHNOLOGY,,}/servers/"
    ovpnName="${1}.ovpn"
    
    log "Downloading: ${nordvpn_cdn}${ovpnName}"
    curl ${nordvpn_cdn}${ovpnName} -o "${ovpnName}"
}



######## Customize downloaded configuration files
# Modify '*.ovpn' file(s) to search credentials in '/config/openvpn-credentials.txt' (created by start script)
# and replace default ping arguments by more desirable values in this context (overriden by eventual openvpn command line options)

update_hostname() {
    log "Checking line endings"
    sed -i 's/^M$//' *.ovpn
    # Update configs with correct options
    log "Updating configs for docker-transmission-openvpn"
    sed -i 's=auth-user-pass=auth-user-pass /config/openvpn-credentials.txt=g' *.ovpn
    # Replace default ping values
    sed -i 's/ping .*/inactive 3600 ping 10/g' *.ovpn
    sed -i 's/ping-restart .*/ping-exit 60/g' *.ovpn
    sed -i 's/ping-timer-rem.*//g' *.ovpn
}



######## Script
# Expected environment variables:
# NORDVPN_CONFIGNAME is optional (select server to be downloaded by name directly, if set all other variables are ignored)
# NORDVPN_COUNTRY    is required, recommendation algorithm ignores all other filters if country is not set (result is not guaranteed to support tcp or udp technology), defaults to 'fr' otherwise
# NORDVPN_TECHNOLOGY is required to be 'udp' or 'tcp' for selection of server, defaults to 'tcp' otherwise
# NORDVPN_GROUP      is optional (if not set, relies on 'recommended' server algorithm)

# If the script is called from elsewhere come back to script directory (downloaded content will be stored here also)
cd "${0%/*}"
script_init


#Checking mandatory variables and eventually set default values
if [[ -z ${NORDVPN_COUNTRY} ]] && [[ -z "$NORDVPN_CONFIGNAME" ]]; then
    NORDVPN_COUNTRY='fr'
    log "Environment variable 'NORDVPN_COUNTRY' is not set but required. Using default value '${NORDVPN_COUNTRY}'."
fi

if [[ "${NORDVPN_TECHNOLOGY,,}" != "udp" ]] && [[ "${NORDVPN_TECHNOLOGY,,}" != "tcp" ]] && [[ -z "$NORDVPN_CONFIGNAME" ]]; then
    log "Environment variable 'NORDVPN_TECHNOLOGY' is invalid (value: ${NORDVPN_TECHNOLOGY:-not set}). Using default value 'tcp'."
    NORDVPN_TECHNOLOGY='tcp'
fi


log "Removing previously downloaded configs"
find . ! -iname '*.sh' -type f -delete


if [[ -n $NORDVPN_CONFIGNAME ]]; then
    # A config name is specified directly (e.g. it69.nordvpn.com.tcp)
    selected=${NORDVPN_CONFIGNAME,,}
else
    # Try to select best server using eventual values in "NORDVPN_COUNTRY", "NORDVPN_GROUP", and "NORDVPN_TECHNOLOGY"
    selected="$(select_hostname).${NORDVPN_TECHNOLOGY,,}"
fi


download_hostname ${selected}
update_hostname


# Return value to calling script
echo "${selected}"


