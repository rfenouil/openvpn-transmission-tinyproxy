#!/bin/bash

/importedScripts/transmission/start_transmission.sh "$@"
/importedScripts/tinyproxy/start_tinyproxy.sh
