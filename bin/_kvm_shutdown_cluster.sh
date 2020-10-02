#!/usr/bin/env bash

# source ./scripts/variables.sh

set +eu # Don't bail on failure

echo "This will take some time"
echo "Monitor running VMs using this command (copy/paste on another terminal)"
echo "watch 'virsh list --state-running'"

# Not using hosts file or variable, we want to control the sequence
# TODO: sort by roles from hosts file
declare -a hosts=("ad" "gw" "host3" "host2" "host1" "controller")

for host in "${hosts[@]}"; do
    echo "Shutting down ${host}"
    virsh shutdown --domain ${host}
    while true; do
        howmany=$( virsh list --state-running | grep ${host} | wc -l )
        if [ ${howmany} -eq 0 ]; then
            break
        fi
    done
    echo "${host} is down"
done

# ssh -o StrictHostKeyChecking=no -i "${LOCAL_SSH_PRV_KEY_PATH}" -T centos@${AD_PRV_IP} "nohup sudo reboot </dev/null &" || true

### Proper service shutdown sequence
# systemctl stop bds-worker
# systemctl stop bds-controller

