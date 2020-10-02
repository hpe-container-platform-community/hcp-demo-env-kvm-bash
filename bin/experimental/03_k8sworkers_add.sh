#!/bin/bash

HOST_IPS=( "$@" )

set -e # abort on error
set -u # abort on undefined variable

if [[ ! -d generated ]]; then
   echo "This file should be executed from the project directory"
   exit 1
fi

./scripts/check_prerequisites.sh
source ./scripts/variables.sh

pip3 install --quiet --upgrade --user hpecp

# use the project's HPECP CLI config file
export HPECP_CONFIG_FILE="./generated/hpecp.conf"

# Test CLI is able to connect
echo "Platform ID: $(hpecp license platform-id)"

echo "Adding workers"
WRKR_IDS=()
for WRKR in ${HOST_IPS[@]}; do
    echo "   worker $WRKR"
    CMD="hpecp k8sworker create-with-ssh-key --ip ${WRKR} --ssh-key-file ./generated/controller.prv_key"
    WRKR_ID="$($CMD)"
    echo "       id $WRKR_ID"
    WRKR_IDS+=($WRKR_ID)
done

echo "Configuring ${#WRKR_IDS[@]} workers in parallel"
for WRKR in ${WRKR_IDS[@]}; do
    {
        echo "   worker $WRKR"
        hpecp k8sworker wait-for-status ${WRKR} --status  "['storage_pending']" --timeout-secs 1800
        hpecp k8sworker set-storage --id ${WRKR} --persistent-disks=/dev/vdb --ephemeral-disks=/dev/vdc
        hpecp k8sworker wait-for-status ${WRKR} --status  "['ready']" --timeout-secs 1800
    } &
done

wait 
