#!/bin/bash

set -e # abort on error
set -u # abort on undefined variable

source "./scripts/variables.sh"
source "./scripts/functions.sh"

print_header "Installing HPECP CLI to local machine"
export HPECP_CONFIG_FILE=generated/hpecp.conf
export HPECP_LOG_CONFIG_FILE=${PWD}/generated/hpecp_cli_logging.conf
pip3 uninstall -y hpecp || true # uninstall if exists
pip3 install --user --upgrade hpecp

HPECP_VERSION=$(hpecp config get --query 'objects.[bds_global_version]' --output text)
echo "HPECP Version: ${HPECP_VERSION}"

if [[ "$MAPR_CLUSTER1_COUNT" != "0" ]]; then
   print_header "Installing MAPR Cluster 1"
   CLUSTER_ID=1
   ./scripts/mapr_install.sh ${CLUSTER_ID} || true # ignore errors
   ./scripts/end_user_scripts/standalone_mapr/setup_ubuntu_mapr_sssd.sh ${CLUSTER_ID} || true # ignore errors
fi

if [[ "$MAPR_CLUSTER2_COUNT" != "0" ]]; then
   print_header "Installing MAPR Cluster 2"
   CLUSTER_ID=2
   ./scripts/mapr_install.sh ${CLUSTER_ID} || true # ignore errors
   ./scripts/end_user_scripts/standalone_mapr/setup_ubuntu_mapr_sssd.sh ${CLUSTER_ID} || true # ignore errors
fi

print_header "Configuring Global Active Directory in HPE CP"
./bin/experimental/01_configure_global_active_directory.sh

print_header "Adding a Gateway to HPE CP"
./bin/experimental/02_gateway_add.sh

if [[ "${INSTALL_WITH_SSL}" == "True" ]]; then
   print_header "Setting Gateway SSL"
   ./bin/experimental/set_gateway_ssl.sh
fi

print_header "Configuring Active Directory in Demo Tenant"
./bin/experimental/setup_demo_tenant_ad.sh

if [[ $HPECP_VERSION == "5.0"* ]]; then
   # 5.1+ embedded mapr is configured automatically with SSSD
   print_header "Configuring Active Directory on HCP Embedded DF"
   ./scripts/end_user_scripts/embedded_mapr/1_setup_epic_mapr_sssd.sh
fi

print_header "Configure Active Directory on RDP Host"
./scripts/end_user_scripts/embedded_mapr/2_setup_ubuntu_mapr_sssd_and_mapr_client.sh

print_header "Add ad_admin1 to HCP Embedded DF"
./bin/df-cluster-acl-ad_admin1.sh # add the ad_admin1 user to the cluster

set +e # ignore errors
print_header "Create Datatap to HCP Embedded DF"
./scripts/end_user_scripts/embedded_mapr/3_setup_datatap_new.sh
set -e

print_header "Enable Virtual Nodes on Controller"
./bin/experimental/epic_enable_virtual_node_assignment.sh

WORKER_HOST_1_IP=${WRKR_PRV_IPS[0]}
WORKER_HOST_2_IP=${WRKR_PRV_IPS[1]}

print_header "Setup two hosts as K8s workers"
./bin/experimental/03_k8sworkers_add.sh "${WORKER_HOST_1_IP}" "${WORKER_HOST_2_IP}" # add 2 EC2 hosts as k8s workers

print_header "Create k8s cluster and tenant"
./bin/experimental/04_k8scluster_create.sh

print_header "Add KD Spark Cluster"
./bin/experimental/05_kubedirector_spark_create.sh

WORKER_HOST_3_IP=${WRKR_PRV_IPS[2]}

print_header "Setup one host as EPIC workers"
./bin/experimental/epic_workers_add.sh "${WORKER_HOST_3_IP}" # add 1 EC2 hosts as Epic worker


if [[ "$MAPR_CLUSTER1_COUNT" == "3" ]]; then
   print_header "Patch DataTap on HCP hosts"
   # Only run this on a 5.1 or lower installer.  Do not run this on 5.1.1+
   #./scripts/end_user_scripts/patch_datatap_5.1.1.sh

   print_header "Setup Datatap to external MAPR cluster 1"
   ./scripts/end_user_scripts/standalone_mapr/setup_datatap_5.1.sh

   print_header "Setup Fuse mount on RDP host to external MAPR cluster 1"
   ./scripts/end_user_scripts/standalone_mapr/setup_ubuntu_mapr_client.sh
fi

# install images last because operations requiring system to be quiesced 
# such as site lockdown may have to wait a long time for the installs
# You can install just spark231 or everything

print_header "Installing EPIC Spark 23x Image"
./bin/experimental/epic_catalog_image_install_spark23.sh

print_header "Installing EPIC Spark 24x Image"
./bin/experimental/epic_catalog_image_install_spark24.sh

print_header "Add EPIC TensorFlow113CPU Cluster"
./bin/experimental/epic_catalog_image_install_by_name.sh TensorFlow113CPU

print_header "Add EPIC CentOS 7.x Cluster"
./bin/experimental/epic_catalog_image_install_by_name.sh "CentOS 7.x"

# uncommment below to install all images
#./bin/experimental/epic_catalog_image_install_all.sh

# print_header "Check EPIC Image status"
# ./bin/experimental/epic_catalog_image_status.sh

print_header "Add EPIC Spark 24x Cluster"
./bin/experimental/epic_spark24_cluster_deploy.sh

# uncomment to set the EPIC CPU allocation ratio
# print_header "Set HCP CPU allocation ratio to 2"
# ./bin/experimental/epic_set_cpu_allocation_ratio.sh

# After setting CPU allocation ratio, SSL get erased
# run the following to reset it.
# if [[ "${INSTALL_WITH_SSL}" == "True" ]]; then
#    print_header "Setting Gateway SSL"
#    ./bin/experimental/set_gateway_ssl.sh
# fi
