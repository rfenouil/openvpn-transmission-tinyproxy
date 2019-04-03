#!/bin/bash

echo "tunnelUp: Tunnel is up, starting transmission and tinyproxy..."

/importedScripts/transmission/start_transmission.sh "$@"
/importedScripts/tinyproxy/start_tinyproxy.sh

echo "tunnelUp: transmission and tinyproxy startup scripts executed, external IP is : $(curl -s https://ipecho.net/plain)" 