#!/bin/bash

echo "=> tunnelDown script starting <="

/importedScripts/transmission/stop_transmission.sh
/importedScripts/tinyproxy/stop_tinyproxy.sh

echo "=> tunnelDown script finished <="