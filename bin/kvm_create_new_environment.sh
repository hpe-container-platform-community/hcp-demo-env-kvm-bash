#!/usr/bin/env bash

# This aims to replicate the automation of deployment for HPE Container Platform on Redhat KVM
# Heavily modified from https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/blob/master/bin/create_new_environment_from_scratch.sh
# Tested on Redhat 8.2 host
# Modifications done to replace terraform with virsh scripts & cater for running behind corporate proxy

set -e # abort on error
set -u # abort on undefined variable
set +x

source "scripts/kvm_functions.sh"
echo "LOG: $0 (START) $(date -R)"

# Ensure that we have all the scripts available
./bin/kvm_collect_scripts_from_github.sh

./scripts/check_prerequisites.sh

source "scripts/functions.sh"
source "etc/kvm_config.sh"

# Need the key pair for paswordless login
if [[ ! -f  "${LOCAL_SSH_PRV_KEY_PATH}" ]]; then
   [[ -d "${OUT_DIR}" ]] || mkdir ${OUT_DIR}
   ssh-keygen -m pem -t rsa -N "" -f "${LOCAL_SSH_PRV_KEY_PATH}"
   mv "${LOCAL_SSH_PRV_KEY_PATH}.pub" "${LOCAL_SSH_PUB_KEY_PATH}"
   chmod 600 "${LOCAL_SSH_PRV_KEY_PATH}"
fi

echo "Setting up network"
create_network

# Create Dirs/files
mkdir -p "${VM_DIR}" || true
[ ! -f "${HOSTS_FILE}" ] && touch ${HOSTS_FILE}

# Create VMs
for (( i = 0; i < ${#hosts[@]}; ++i )); do
   create_vm ${hosts[i]} ${cpus[i]} ${mems[i]} ${roles[i]} ${disks[i]}
done

# Get updated variables
source "./scripts/variables.sh"

if [ "${BEHIND_PROXY}" == "True" ]; then
   print_header "Updating Proxy settings on all hosts"
   ./scripts/kvm_set_proxy.sh
   # To update local no_proxy list
   sudo sed -i "/^export no_proxy/ s/$/,${GATW_PUB_DNS}/" ${SYSTEM_PROXY_FILE}
   source ${SYSTEM_PROXY_FILE}
fi

# Hack for proxy # Need to update after env set via variables.sh
sed -i 's/\-O \${EPIC_FILENAME} \"\${EPIC_DL_URL}\"/-O ${EPIC_FILENAME} \${WGET_OPTIONS} "${EPIC_DL_URL}"/' ./scripts/bluedata_install.sh

if [ "${AD_SERVER_ENABLED}" == "True" ]; then
   scp -o StrictHostKeyChecking=no -i "${LOCAL_SSH_PRV_KEY_PATH}" -T \
      ./scripts/ad_files/* centos@${AD_PRV_IP}:~/
   ssh -o StrictHostKeyChecking=no -i "${LOCAL_SSH_PRV_KEY_PATH}" -T centos@${AD_PRV_IP} <<EOT
      ### Hack to avoid same run each time with updates, possibly should move to post create
      [ -f ad_set_posix_classes.log ] && exit 0
      set -ex
      sudo yum install -y -q docker openldap-clients
      sudo service docker start
      sudo systemctl enable docker
      . /home/centos/run_ad.sh
      sleep 120
      . /home/centos/ldif_modify.sh
EOT
fi

print_header "Running ./scripts/post_refresh_or_apply.sh"
./scripts/post_refresh_or_apply.sh

print_header "Installing HCP"
./scripts/bluedata_install.sh
# ready to access from local network, so adding nat/forward rules
# ./scripts/kvm_ipforwarding.sh controller on

print_header "Installing HPECP CLI on Controller"
./bin/experimental/install_hpecp_cli.sh 
if [[ -f ./etc/postcreate.sh ]]; then
#    print_header "Uploading Spark image files to Controller"
#    ssh -o StrictHostKeyChecking=no -i "${LOCAL_SSH_PRV_KEY_PATH}" -T centos@${CTRL_PUB_IP} << ENDSSH
# sudo wget --no-proxy -e dotbytes=10M -c -nd -np --no-clobber -P /srv/bluedata/catalog ${IMAGE_CATALOG}/bdcatalog-centos7-bluedata-spark231juphub7xssl-3.4.bin
# sudo wget --no-proxy -e dotbytes=10M -c -nd -np --no-clobber -P /srv/bluedata/catalog ${IMAGE_CATALOG}/bdcatalog-centos7-bluedata-spark240juphub7xssl-2.8.bin
# sudo chmod 750 /srv/bluedata/catalog/*
# sudo chown apache:apache /srv/bluedata/catalog/*
# sudo systemctl restart bds-controller
# ENDSSH
   print_header "Found ./etc/postcreate.sh so executing it"
   ./etc/postcreate.sh && mv ./etc/postcreate.sh ./etc/postcreate.sh.completed
else
   print_header "./etc/postcreate.sh not found - skipping."
fi

cat > ./generated/get_public_endpoints.sh <<EOF

Controller: ssh -o StrictHostKeyChecking=no -i ${LOCAL_SSH_PRV_KEY_PATH} centos@${CTRL_PRV_IP}
Gateway: ssh -o StrictHostKeyChecking=no -i ${LOCAL_SSH_PRV_KEY_PATH} centos@${GATW_PRV_IP}
AD: ssh -o StrictHostKeyChecking=no -i ${LOCAL_SSH_PRV_KEY_PATH} centos@${AD_PRV_IP}
Host1: ssh -o StrictHostKeyChecking=no -i ${LOCAL_SSH_PRV_KEY_PATH} centos@${WRKR_PRV_IPS[0]}
Host2: ssh -o StrictHostKeyChecking=no -i ${LOCAL_SSH_PRV_KEY_PATH} centos@${WRKR_PRV_IPS[1]}
Host3: ssh -o StrictHostKeyChecking=no -i ${LOCAL_SSH_PRV_KEY_PATH} centos@${WRKR_PRV_IPS[2]}

EOF

echo "ssh -o StrictHostKeyChecking=no -i ${LOCAL_SSH_PRV_KEY_PATH} centos@${CTRL_PRV_IP} \$1" > ./generated/ssh_controller.sh
echo "ssh -o StrictHostKeyChecking=no -i ${LOCAL_SSH_PRV_KEY_PATH} centos@${GATW_PRV_IP} \$1" > ./generated/ssh_gateway.sh
echo "ssh -o StrictHostKeyChecking=no -i ${LOCAL_SSH_PRV_KEY_PATH} centos@${AD_PRV_IP} \$1" > ./generated/ssh_ad.sh
echo "ssh -o StrictHostKeyChecking=no -i ${LOCAL_SSH_PRV_KEY_PATH} centos@${WRKR_PRV_IPS[0]} \$1" > ./generated/ssh_host1.sh
echo "ssh -o StrictHostKeyChecking=no -i ${LOCAL_SSH_PRV_KEY_PATH} centos@${WRKR_PRV_IPS[1]} \$1" > ./generated/ssh_host2.sh
echo "ssh -o StrictHostKeyChecking=no -i ${LOCAL_SSH_PRV_KEY_PATH} centos@${WRKR_PRV_IPS[2]} \$1" > ./generated/ssh_host3.sh
chmod +x ./generated/*.sh

# # Download image catalog to controller
# if [ ! -z "${IMAGE_CATALOG}" ]; then
#    echo -n "Do you want to download images from local catalog?"
#    read -n 1 res
#    if [ "$res" == [Yy] ]; then
#       echo "This will take long..."
#       ./generated/ssh_controller.sh "wget --no-proxy -e dotbytes=10M -c -nd -np --no-clobber -P /srv/bluedata/catalog ${IMAGE_CATALOG} && chmod 750 /srv/bluedata/catalog/*"
#    else
#       echo "Skipped catalog download"
#    fi
# fi

# if [ "${CREATE_EIP_GATEWAY}" == "True" ]; then
#    # Switch to gateway
#    ./scripts/kvm_ipforwarding.sh controller off
#    ./scripts/kvm_ipforwarding.sh gw on
#    ## TODO: need to verify network name and bridge interface name
#    # sudo virsh attach-interface --domain gw --type bridge --source virbr0 --model virtio --config --live  
#    # myip=$(virsh domifaddr gw)
#    # GATW_PUB_IP=${myip}
# fi

print_term_width '-'
echo "Run ./generated/get_public_endpoints.sh for all connection details."
print_term_width '-'

print_term_width '='

echo "LOG: $0 (FINISH) $(date -R)"
