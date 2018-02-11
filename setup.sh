#!/usr/bin/env bash
set -e

# Setup script for starting out in a fresh environment.
# This script must fetch git and python to start running the more complicated main scripts
# It does this by delegating to OS-specific installers in the setup folder

### Helper functions

_vsi_read_os_release_field () {
    # essentially grep ^<name>= | sed s/name=//
    local raw_value="$(grep '^'"${1}"'=' /etc/os-release | sed 's/'"${1}"'=//')"
    # unquote by directly injecting, without quotes
    eval printf %s $raw_value
}

_vsi_get_script () {
    curl -# -s --fail \
        https://raw.githubusercontent.com/kenzierocks/very-shell-installer/"$VSI_BRANCH"/setup/"$1".sh \
            >"$2"
}

_vsi_echo () {
    printf "[#VSI#] %s\n" "$1" >&2
}

_vsi_is_cmd_present () {
	command -v "$1" > /dev/null 2>&1
}

_vsi_require_cmd () {
    if ! _vsi_is_cmd_present "$1"; then
        _vsi_echo "'$1' is required to run this script."
        exit 2
    fi
}

_vsi_env_default () {
    local name="$1"
    local value="$2"

    local current_value="${!name}"
    if [ -z ${current_value:+x} ]; then
        eval "${name}=\"${value}\""
    fi
}


### Configuration
_vsi_env_default XDG_CONFIG_HOME "$HOME/.config"
_vsi_env_default INSTALL_FOLDER "$XDG_CONFIG_HOME/very-shell-installer"

_vsi_env_default VSI_BRANCH master

### Actual script

# Requirements
_vsi_require_cmd curl
_vsi_require_cmd md5sum

_vsi_echo "Creating installation folder at $INSTALL_FOLDER..."
mkdir -p "$INSTALL_FOLDER"

# Generic OS detection
MAC=mac
WINDOWS=windows
LINUX=linux

UBUNTU=ubuntu
DEBIAN=debian

BSD=bsd
SOLARIS=solaris
UNKNOWN=unknown

_vsi_echo "Detecting OS..."

generic_os="$UNKNOWN"
case "$OSTYPE" in
    darwin*) generic_os="$MAC" ;;
    linux*) generic_os="$LINUX" ;;
    solaris*) generic_os="$SOLARIS" ;;
    bsd*) generic_os="$BSD" ;;
    # No support for windows -- but still recognize it for better errors
    msys*|cygwin*|win32) generic_os="$WINDOWS" ;;
    # Attach the variable to the UNKNOWN id for more info
    *) generic_os="$UNKNOWN-$OSTYPE" ;;
esac

# Further specify what linux we're talking about
if [ "$generic_os" == "$LINUX" ] && [ -f /etc/os-release ]; then
    # Parse os-release
    id_value="$(_vsi_read_os_release_field ID)"
    version_value="$(_vsi_read_os_release_field VERSION_ID)"
    if [ "x$id_value" != "x" ]; then
        generic_os="$id_value"
        os_release_version="$version_value"
    fi
fi

os_version="$UNKNOWN"
case "$generic_os" in
    "$MAC") os_version="$(sw_vers -productVersion)" ;;
    "$LINUX") ;; # unsupported for version checking
    "$UBUNTU"|"$DEBIAN") os_version="$os_release_version" ;;
esac

_vsi_echo "Detected OS $generic_os v$os_version."


script_id=none
script_args=()
case "$generic_os" in
    # This is where we inject version specific overrides, if needed

    "$MAC"|"$UBUNTU"|"$DEBIAN") # OSes with no overrides
        script_id="$generic_os" ;;

    # yum goes here -- I don't know how to use it though, so it's not written out

    # Anything unhandled
    *) script_args=("$generic_os+$os_version") ;;
esac

_vsi_echo "Fetching script $script_id..."

dl_wip_file="$INSTALL_FOLDER/.dl.sh"
script_file="$INSTALL_FOLDER/$script_id.sh"

set +e
_vsi_get_script "$script_id" "$dl_wip_file"
_get_script_exit_code="$?"
set -e

if [ ! -f "$script_file" ]; then
    if [ "$_get_script_exit_code" -ne 0 ]; then
        _vsi_echo "Failed to fetch script."
        exit 1
    fi
    _vsi_echo "Script downloaded."
    mv "$dl_wip_file" "$script_file"
elif [ "$_get_script_exit_code" -eq 0 ]; then
    remote_md5="$(md5sum <"$dl_wip_file")"
    local_md5="$(md5sum <"$script_file")"
    _vsi_echo "Verifying script version... (remote: $remote_md5; local: $local_md5)"
    if [ "$remote_md5" != "$local_md5" ]; then
        _vsi_echo "Script updated."
        mv "$dl_wip_file" "$script_file"
    fi
else
    _vsi_echo "Warning: unable to check for new script version."
fi

_vsi_echo "Executing script..."

chmod +x "$script_file"
"$script_file" "${script_args[@]}"

cd "$INSTALL_FOLDER"
if [ ! -d git-repo/.git ]; then
    _vsi_echo "Cloning VSI from $VSI_BRANCH..."
    git clone https://github.com/kenzierocks/very-shell-installer --branch "$VSI_BRANCH" git-repo
    cd git-repo
else
    cd git-repo
    _vsi_echo "Fetching..."
    git fetch
    _vsi_echo "Checking out $VSI_BRANCH..."
    git checkout "$VSI_BRANCH"
fi

python3 ./main.py
