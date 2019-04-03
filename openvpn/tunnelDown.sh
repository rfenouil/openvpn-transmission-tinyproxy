#!/bin/bash

echo "tunnelDown: Tunnel is down, stopping transmission and tinyproxy..."

/importedScripts/transmission/stop_transmission.sh
/importedScripts/tinyproxy/stop_tinyproxy.sh

echo "tunnelDown: transmission and tinyproxy shutdown scripts executed :(" 