#!/usr/bin/env bash
set -e

### Helper functions

_vsi_is_cmd_present () {
	command -v "$1" > /dev/null 2>&1
}

### Actual script

sudo -p 'Hi, %u, please enter your password to continue using VSI:' true

alias _vsi_sudo=sudo -n -H

if ! _vsi_is_cmd_present apt ; then
    _vsi_sudo apt-get install apt
fi

_vsi_sudo apt install git
_vsi_sudo apt install python3
_vsi_sudo apt install python3-pip
