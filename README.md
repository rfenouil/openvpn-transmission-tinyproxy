# OpenVPN, Transmission with WebUI, and VPN proxy

[![Docker Automated build](https://img.shields.io/docker/automated/fenouil/openvpn-transmission-tinyproxy.svg)](https://hub.docker.com/r/fenouil/openvpn-transmission-tinyproxy/)
[![Docker Pulls](https://img.shields.io/docker/pulls/fenouil/openvpn-transmission-tinyproxy.svg)](https://hub.docker.com/r/fenouil/openvpn-transmission-tinyproxy/)


## About this repository copy

All initial work is imported from another repository: haugene/docker-transmission-openvpn (commit 46ba5e0995dfbb185abd9e083e1edec3ce6fb785)
This new repository has been created for maintaining a working arm version, to be used on my Rock64 device with openmediavault (but should work on other arm configurations too).

All configuration files bundled in initial repository are removed.
I use NordVPN and I plan to rely on either:
- a small amount of openVPN configuration files (*.ovpn) files selected and downloaded manually
- a script that extracts 'recommended' server from NordVPN website (if user provides credentials as environment variables)

I use this project as an exercise to understand better how docker technology works.
Since my needs are less complex than what is implemented in original repository, most of my work consists in stripping-down and simplifying original code.

Documentation (this file) has been adapted to this repository but feel free to report inconsistencies or comments in issues.


## Introduction

This container contains OpenVPN and Transmission with a configuration
where Transmission is running only when OpenVPN has an active tunnel.

It also bundles an installation of Tinyproxy to proxy web traffic over your VPN.


## Main difference with original repository
 
### Supported providers

Bundled providers and config files were removed from this copy of the repository.

As opposed to the original concept, the idea here is that the user manually selects and download openvpn (*.ovpn) files and put them in the corresponding volume. These files must be 'ready to use' (i.e. it must already contain credentials, while scripts from original repository create them with provided login and password).

A random will be chosen on startup, unless a specific one is selected on startup (see variable `OPENVPN_CONFIG`). 


## Run container from Docker registry
The container is available from the Docker registry and this is the simplest way to get it.
To run the container use this command:

```
$ docker run --cap-add=NET_ADMIN --device=/dev/net/tun -d \
              -v /your/storage/path/:/data \
              -v /your/ovpnFiles/path:/ovpnFiles \
              -v /etc/localtime:/etc/localtime:ro \
              -e LOCAL_NETWORK=192.168.0.0/16 \
              --log-driver json-file \
              --log-opt max-size=10m \
              -p 9091:9091 \
              fenouil/openvpn-transmission-tinyproxy
```

The container expects a 'data' volume to be mounted.
This is where Transmission will store your downloads, incomplete downloads and look for a watch directory for new .torrent files.
By default a folder named transmission-home will also be created under /data, this is where Transmission stores its state.

A second (optional) volume is expected to contain openVPN configuration files that will be used to establish connection.

If you did not prepare openVPN configuration files and want to rely on NordVPN 'recommended' selection of server, you can omit this volume but you must set the environment variables `OPENVPN_USERNAME` and `OPENVPN_PASSWORD` to allow scripts preparing the configuration file for you.


The `OPENVPN_CONFIG` is an optional variable.

If user provides openVPN configuration files in a folder, he can use this variable to provide a regular expression selecting a sublist of files from which connection will be made.

```
-e "OPENVPN_CONFIG=FR*"
```

If user provides username and password as environment variables (rely on 'recommended' server configuration from NordVPN website), it will be used to select server country (TODO: add available values).

```
-e "OPENVPN_CONFIG=FR"
```


If you provide a list and the selected server goes down, after the value of ping-timeout the container will be restarted and a server will be randomly chosen, note that the faulty server can be chosen again, if this should occur, the container will be restarted again until a working server is selected.

To make sure this work in all cases, you should add ```--pull-filter ignore ping``` to your OPENVPN_OPTS variable. ???


### Required environment options

None, all mandatory VPN informations (including credentials) should already be contained in openVPN configuration files (*.ovpn) provided by user.

If user wants to use NordVPN recommended server, he must provide environment variables `OPENVPN_USERNAME` and `OPENVPN_PASSWORD`.


### Network configuration options
| Variable | Function | Example |
|----------|----------|-------|
|`OPENVPN_CONFIG` | Sets the OpenVPN endpoint to connect to. | `OPENVPN_CONFIG=UK Southampton`|
|`OPENVPN_OPTS` | Will be passed to OpenVPN on startup | See [OpenVPN doc](https://openvpn.net/index.php/open-source/documentation/manuals/65-openvpn-20x-manpage.html) |
|`LOCAL_NETWORK` | Sets the local network that should have access. Accepts comma separated list. | `LOCAL_NETWORK=192.168.0.0/24`|
|`CREATE_TUN_DEVICE` | Creates /dev/net/tun device inside the container, mitigates the need mount the device from the host | `CREATE_TUN_DEVICE=true`|

### Firewall configuration options
When enabled, the firewall blocks everything except traffic to the peer port and traffic to the rpc port from the LOCAL_NETWORK and the internal docker gateway.

If TRANSMISSION_PEER_PORT_RANDOM_ON_START is enabled then it allows traffic to the range of peer ports defined by TRANSMISSION_PEER_PORT_RANDOM_HIGH and TRANSMISSION_PEER_PORT_RANDOM_LOW.

| Variable | Function | Example |
|----------|----------|-------|
|`ENABLE_UFW` | Enables the firewall | `ENABLE_UFW=true`|
|`UFW_ALLOW_GW_NET` | Allows the gateway network through the firewall. Off defaults to only allowing the gateway. | `UFW_ALLOW_GW_NET=true`|
|`UFW_EXTRA_PORTS` | Allows the comma separated list of ports through the firewall. Respects UFW_ALLOW_GW_NET. | `UFW_EXTRA_PORTS=9910,23561,443`|
|`UFW_DISABLE_IPTABLES_REJECT` | Prevents the use of `REJECT` in the `iptables` rules, for hosts without the `ipt_REJECT` module (such as the Synology NAS). | `UFW_DISABLE_IPTABLES_REJECT=true`|

### Permission configuration options ???
By default the startup script applies a default set of permissions and ownership on the transmission download, watch and incomplete directories. The GLOBAL_APPLY_PERMISSIONS directive can be used to disable this functionality.

| Variable | Function | Example |
|----------|----------|-------|
|`GLOBAL_APPLY_PERMISSIONS` | Disable setting of default permissions | `GLOBAL_APPLY_PERMISSIONS=false`|

### Alternative web UIs
You can override the default web UI by setting the ```TRANSMISSION_WEB_HOME``` environment variable. If set, Transmission will look there for the Web Interface files, such as the javascript, html, and graphics files.

[Combustion UI](https://github.com/Secretmapper/combustion), [Kettu](https://github.com/endor/kettu) and [Transmission-Web-Control](https://github.com/ronggang/transmission-web-control/) come bundled with the container. You can enable either of them by setting```TRANSMISSION_WEB_UI=combustion```, ```TRANSMISSION_WEB_UI=kettu``` or ```TRANSMISSION_WEB_UI=transmission-web-control```, respectively. Note that this will override the ```TRANSMISSION_WEB_HOME``` variable if set.

| Variable | Function | Example |
|----------|----------|-------|
|`TRANSMISSION_WEB_HOME` | Set Transmission web home | `TRANSMISSION_WEB_HOME=/path/to/web/ui`|
|`TRANSMISSION_WEB_UI` | Use the specified bundled web UI | `TRANSMISSION_WEB_UI=combustion`, `TRANSMISSION_WEB_UI=kettu` or `TRANSMISSION_WEB_UI=transmission-web-control`|

### Transmission configuration options

You may override Transmission options by setting the appropriate environment variable.

The environment variables are the same name as used in the transmission settings.json file
and follow the format given in these examples:

| Transmission variable name | Environment variable name |
|----------------------------|---------------------------|
| `speed-limit-up` | `TRANSMISSION_SPEED_LIMIT_UP` |
| `speed-limit-up-enabled` | `TRANSMISSION_SPEED_LIMIT_UP_ENABLED` |
| `ratio-limit` | `TRANSMISSION_RATIO_LIMIT` |
| `ratio-limit-enabled` | `TRANSMISSION_RATIO_LIMIT_ENABLED` |

As you can see the variables are prefixed with `TRANSMISSION_`, the variable is capitalized, and `-` is converted to `_`.

Transmission options changed in the WebUI or in settings.json will be overridden at startup and will not survive after a reboot of the container. You may want to use these variables in order to keep your preferences.

PS: `TRANSMISSION_BIND_ADDRESS_IPV4` will be overridden to the IP assigned to your OpenVPN tunnel interface.
This is to prevent leaking the host IP.

### Web proxy configuration options

This container also contains a web-proxy server to allow you to tunnel your web-browser traffic through the same OpenVPN tunnel.
This is useful if you are using a private tracker that needs to see you login from the same IP address you are torrenting from.
The default listening port is 8888. Note that only ports above 1024 can be specified as all ports below 1024 are privileged
and would otherwise require root permissions to run.
Remember to add a port binding for your selected (or default) port when starting the container.

| Variable | Function | Example |
|----------|----------|-------|
|`WEBPROXY_ENABLED` | Enables the web proxy | `WEBPROXY_ENABLED=true`|
|`WEBPROXY_PORT` | Sets the listening port | `WEBPROXY_PORT=8888` |

### User configuration options

By default everything will run as the root user. However, it is possible to change who runs the transmission process.
You may set the following parameters to customize the user id that runs transmission.

| Variable | Function | Example |
|----------|----------|-------|
|`PUID` | Sets the user id who will run transmission | `PUID=1000`|
|`PGID` | Sets the group id for the transmission user | `PGID=100` |

### Dropping default route from iptables (advanced) (nordVPN compatible ???)

Some VPNs do not override the default route, but rather set other routes with a lower metric.
This might lead to the default route (your untunneled connection) to be used.

To drop the default route set the environment variable `DROP_DEFAULT_ROUTE` to `true`.

*Note*: This is not compatible with all VPNs. You can check your iptables routing with the `ip r` command in a running container.

### Custom pre/post scripts

If you ever need to run custom code before or after transmission is executed or stopped, you can use the custom scripts feature.
Custom scripts are located in the /scripts directory which is empty by default.
To enable this feature, you'll need to mount the /scripts directory.

Once /scripts is mounted you'll need to write your custom code in the following bash shell scripts:

| Script | Function |
|----------|----------|
|/scripts/openvpn-pre-start.sh | This shell script will be executed before openvpn start |
|/scripts/transmission-pre-start.sh | This shell script will be executed before transmission start |
|/scripts/transmission-post-start.sh | This shell script will be executed after transmission start |
|/scripts/transmission-pre-stop.sh | This shell script will be executed before transmission stop |
|/scripts/transmission-post-stop.sh | This shell script will be executed after transmission stop |

Don't forget to include the #!/bin/bash shebang and to make the scripts executable using chmod a+x


#### Use docker env file
Another way is to use a docker env file where you can easily store all your env variables and maintain multiple configurations for different providers.
In the GitHub repository there is a provided DockerEnv file with all the current transmission and openvpn environment variables. You can use this to create local configurations
by filling in the details and removing the # of the ones you want to use.

Please note that if you pass in env. variables on the command line these will override the ones in the env file.

See explanation of variables above.
To use this env file, use the following to run the docker image:
```
$ docker run --cap-add=NET_ADMIN --device=/dev/net/tun -d \
              -v /your/storage/path/:/data \
              -v /etc/localtime:/etc/localtime:ro \
              --env-file /your/docker/env/file \
              -p 9091:9091 \
              haugene/transmission-openvpn
```

## Access the WebUI

But what's going on? My http://my-host:9091 isn't responding?
This is because the VPN is active, and since docker is running in a different ip range than your client the response
to your request will be treated as "non-local" traffic and therefore be routed out through the VPN interface.


### How to fix this

The container supports the `LOCAL_NETWORK` environment variable. For instance if your local network uses the IP range 192.168.0.0/16 you would pass `-e LOCAL_NETWORK=192.168.0.0/16`.


## Access the RPC

You need to add a / to the end of the URL to be able to connect. Example: http://my-host:9091/transmission/rpc/


## Known issues, tips and tricks

#### Use Google DNS servers
Some have encountered problems with DNS resolving inside the docker container.
This causes trouble because OpenVPN will not be able to resolve the host to connect to.
If you have this problem use dockers --dns flag to override the resolv.conf of the container.
For example use googles dns servers by adding --dns 8.8.8.8 --dns 8.8.4.4 as parameters to the usual run command.


#### Restart container if connection is lost
If the VPN connection fails or the container for any other reason loses connectivity, you want it to recover from it. One way of doing this is to set environment variable `OPENVPN_OPTS=--inactive 3600 --ping 10 --ping-exit 60` and use the --restart=always flag when starting the container. This way OpenVPN will exit if ping fails over a period of time which will stop the container and then the Docker deamon will restart it.


#### Reach sleep or hybernation on your host if no torrents are active
By befault Transmission will always [scrape](https://en.wikipedia.org/wiki/Tracker_scrape) trackers, even if all torrents have completed their activities, or they have been paused manually. This will cause Transmission to be always active, therefore never allow your host server to be inactive and go to sleep/hybernation/whatever. If this is something you want, you can add the following variable when creating the container. It will turn off a hidden setting in Tranmsission which will stop the application to scrape trackers for paused torrents. Transmission will become inactive, and your host will reach the desidered state.
```
-e "TRANSMISSION_SCRAPE_PAUSED_TORRENTS_ENABLED=false"
```
