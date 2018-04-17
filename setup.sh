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

_vsi_echo () {
    printf "[VSI] %s\n" "$1" >&2
}

_vsi_is_cmd_present () {
	command -v "$1" > /dev/null 2>&1
}

_vsi_env_default () {
    local name="$1"
    local value="$2"

    local current_value="${!name}"
    if [ -z ${current_value:+x} ]; then
        eval "${name}=\"${value}\""
    fi
}

_vsi_install () {
    _vsi_echo "Installing..."
    _vsi_echo ""

    _vsi_echo "Cloning repository ${GITHUB_OWNER}/${GITHUB_NAME} to $INSTALL_FOLDER..."
    git clone https://github.com/"$GITHUB_OWNER"/"$GITHUB_NAME" .
    _vsi_echo "Checking out ref $GITHUB_REF..."
    git checkout "$GITHUB_REF"

    _vsi_echo "Installing virtualenv to $INSTALL_FOLDER..."
    git clone --depth 1 https://github.com/pypa/virtualenv "$INSTALL_FOLDER/.virtualenv-pip"
    _vsi_echo "Creating virtual environment..."
    python3 "$INSTALL_FOLDER/.virtualenv-pip/virtualenv.py" -p python3 "$INSTALL_FOLDER/.venv"
    _vsi_echo "Activating virtual environment..."
    . "$INSTALL_FOLDER/.venv/bin/activate"
    _vsi_echo "Installing dependencies..."
    pip3 install -r requirements.txt
    _vsi_echo "Running installer..."
    exec python3 ./main.py
}


### Configuration
_vsi_env_default XDG_CONFIG_HOME "$HOME/.config"
_vsi_env_default INSTALL_FOLDER "$XDG_CONFIG_HOME/very-shell-installer"

_vsi_env_default GITHUB_OWNER "kenzierocks"
_vsi_env_default GITHUB_NAME "very-shell-installer"
_vsi_env_default GITHUB_REF "master"

### Actual script

if [ ! -d "$INSTALL_FOLDER" ]; then
    _vsi_echo "Creating installation folder at $INSTALL_FOLDER..."
    mkdir -p "$INSTALL_FOLDER"
fi
cd "$INSTALL_FOLDER"

if { _vsi_is_cmd_present git && _vsi_is_cmd_present python3 && _vsi_is_cmd_present pip3 ; }; then
    # Requirements satisfied. Go right ahead.
    _vsi_echo "Requirements already satisfied."
    _vsi_install
    exit 0
fi

# Requirements
if ! _vsi_is_cmd_present curl; then
    _vsi_echo "cURL is required to run this script."
    exit 2
fi

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

script_file="$INSTALL_FOLDER/$script_id.sh"

if [ ! -e "$script_file" ]; then
    curl -# -s --fail \
        https://raw.githubusercontent.com/"$GITHUB_OWNER"/"$GITHUB_NAME"/"$GITHUB_REF"/setup/"$script_id".sh \
            >"$script_file" \
        || { _vsi_echo "Failed to fetch script."; rm -f "$script_file" || true; exit 1; }
fi

_vsi_echo "Running script..."
chmod +x "$script_file"
"$script_file" "${script_args[@]}"

_vsi_install
