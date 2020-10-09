#!/usr/bin/env bash

###
# An attempt to reuse scripts from Chris Snow's repository
# https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform
###

# set -e # abort on error
# set -u # abort on undefined variable
set -x

source "scripts/kvm_functions.sh"

# Delete ip forwarding rules
# sudo ./scripts/kvm_ipforwarding.sh controller off
sudo ./scripts/kvm_ipforwarding.sh gateway off

### Remove Network
destroy_network

### Remove VMs
if [ -d ${VM_DIR} ]; then
    dir=($(ls -r ${VM_DIR}))
    for (( i = 0; i < ${#dir[@]}; ++i )); do
        destroy_vm ${dir[i]}
    done
    rm -rf ${VM_DIR}
fi

# Clean host entries in ~/.ssh/known_hosts
sed -i "/${NET}./d" -i ~/.ssh/known_hosts
if [ "${CREATE_EIP_GATEWAY}" == "True" ]; then
    sed -i "/${GATW_PUB_IP}./d" -i ~/.ssh/known_hosts
fi

if [ -d ./generated ]; then
    pushd ./generated > /dev/null
        rm -f bluedata_install_output.txt* get_public_endpoints.sh ssh_*.sh hpecp_cli.log
    popd > /dev/null
fi

# Clean downloaded scripts too
if [ "$1" = "all" ]; then
    pushd ./scripts > /dev/null
        rm -rf end_user_scripts check_prerequisites.sh functions.sh bluedata_install.sh \
            post_refresh_or_apply.sh mapr_install.sh mapr_update.sh verify_ad_server_config.sh 
    popd > /dev/null
    pushd ./etc > /dev/null
        rm -f postcreate.sh hpecp_cli_logging.conf
    popd > /dev/null
    pushd ./bin > /dev/null
        rm -rf df-cluster-acl-ad_admin1.sh experimental
    popd > /dev/null
    if [ -d ./generated ]; then
        pushd ./generated > /dev/null
            rm -f hpecp_cli_logging.conf bluedata_infra_variables.tf \
                ca-cert.pem ca-key.pem cert.pem controller.prv_key controller.pub_key hpecp.conf key.pem 
        popd > /dev/null
    fi    
fi

# Finally remove hosts file
rm -f "${HOSTS_FILE}"

exit 0
