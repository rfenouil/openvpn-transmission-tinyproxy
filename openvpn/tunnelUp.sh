#!/bin/bash

echo "=> tunnelUp script starting <="

/importedScripts/transmission/start_transmission.sh "$@" # Forward network parameters given by openvpn to transmission start script
/importedScripts/tinyproxy/start_tinyproxy.sh

echo "=> tunnelUp script finished <="