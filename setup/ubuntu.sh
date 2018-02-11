#!/usr/bin/env bash
set -e

### Helper functions

_vsi_is_cmd_present () {
	command -v "$1" > /dev/null 2>&1
}

_vsi_echo () {
    printf "[#VSI#] %s\n" "$1" >&2
}

_vsi_sudo () {
    sudo -n -H "$@"
}

_vsi_install () {
    _vsi_echo "Installing $1"
    _vsi_sudo apt install "$1"
}

### Actual script

_vsi_echo "Checking sudo status..."
sudo -p 'Hi, %u, please enter your password to continue using VSI: ' true

if ! _vsi_is_cmd_present apt ; then
    _vsi_echo "Installing apt for you..."
    _vsi_sudo apt-get install apt
fi

_vsi_install git
_vsi_install python3
_vsi_install python3-pip
