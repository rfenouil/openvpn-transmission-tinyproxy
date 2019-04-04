#!/bin/bash

echo "=> tunnelDown script started"

/importedScripts/transmission/stop_transmission.sh
/importedScripts/tinyproxy/stop_tinyproxy.sh

echo "=> tunnelDown executed, Transmission and Tinyproxy shut down :(" 