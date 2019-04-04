#!/bin/bash

echo "=> tunnelUp script started"

/importedScripts/transmission/start_transmission.sh "$@" # Forward network parameters given by openvpn to transmission start script
/importedScripts/tinyproxy/start_tinyproxy.sh

echo "=> tunnelUp executed, external IP is: $(curl -s ipecho.net/plain)"