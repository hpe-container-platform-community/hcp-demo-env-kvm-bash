#!/usr/bin/env bash

set -e # abort on error
set -u # abort on undefined variable

source "./scripts/functions.sh"

command -v python3 >/dev/null 2>&1    || { echo >&2 "I require 'python3' but it's not installed.  Aborting."; exit 1; }
command -v pip3 >/dev/null 2>&1       || { echo >&2 "I require 'pip3' but it's not installed.  Aborting."; exit 1; }

command -v ssh-keygen >/dev/null 2>&1 || { echo >&2 "I require 'ssh-keygen' but it's not installed.  Aborting."; exit 1; }
command -v nc >/dev/null 2>&1         || { echo >&2 "I require 'nc' but it's not installed.  Aborting."; exit 1; }
command -v curl >/dev/null 2>&1       || { echo >&2 "I require 'curl' but it's not installed.  Aborting."; exit 1; }

# Ensure python is able to find packages
REQUIRED_PATH="$(python3 -m site --user-base)/bin"
if [[ :$PATH: != *:"$REQUIRED_PATH":* ]] ; then
    tput setaf 1
    print_term_width '='
    echo "Aborting because PATH variable does not include: $REQUIRED_PATH"
    print_term_width '='
    tput sgr0
    echo
    echo "TIP: You can set the PATH for the current terminal session by running the following command:"
    echo
    echo "   export PATH=\$PATH:$REQUIRED_PATH"
    echo
    echo "To make the PATH setting permanent, add the above line to your ~/.bashrc or ~/.bash_profile"
    print_term_width '-'
    exit 1
fi

python3 -m ipcalc > /dev/null || {
    echo "I require 'ipcalc' python module, but it's not installed.  Aborting."
    echo "Please install with: 'pip3 install --user ipcalc six'"
    exit 1
}

command -v hpecp > /dev/null || {
    echo "I require 'hpecp' python module, but it's not installed.  Aborting."
    echo "Please install with: 'pip3 install --user --upgrade hpecp'"
    exit 1
}
