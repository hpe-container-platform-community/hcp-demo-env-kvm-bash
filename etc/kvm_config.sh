#!/usr/bin/env bash

# Top Level Directory for the project
PROJECT_DIR=/home/hpeadmin/hcp-demo-env-kvm-bash
# Directory to store VMs
VM_DIR="${PROJECT_DIR}"/vms
OUT_DIR="${PROJECT_DIR}"/generated
# File to keep configured hosts
HOSTS_FILE=${OUT_DIR}/hosts
# Repository of image files, ie, CentOS-GenericCloud.qcow2 or ECP installer
CENTOS_IMAGE_FILE=/files/CentOS-7-x86_64-GenericCloud-2003.qcow2
# Local yum repo
LOCAL_YUM_REPO=http://10.1.1.209/repos
# Environment settings
BEHIND_PROXY=True
PROXY_URL="http://proxy.dlg.dubai:3128"
# Convert proxy_url to ip (mainly for containers)
hostpart=$(echo ${PROXY_URL} | awk -F[/:] '{print $4}')
PROXY_IP=$(getent ahostsv4 $(echo $hostpart) | head -1 | cut -d' ' -f1)
PROXY_URL_WITH_IP=${PROXY_URL/${hostpart}/${PROXY_IP}}
# Initialize with local host's no_proxy
SYSTEM_PROXY_FILE="/etc/profile.d/proxy.sh"
NOPROXY=$(grep "^export no_proxy" ${SYSTEM_PROXY_FILE} | cut -d'=' -f2)

LOCAL_REPO_FILE="http://10.1.1.209/repos/dlg.repo"
TIMEZONE="Asia/Dubai"

EPIC_FILENAME=hpe-cp-rhel-release-5.1-3011.bin
EPIC_DL_URL="ftp://10.1.1.209/${EPIC_FILENAME}"
EPIC_OPTIONS='--skipeula'
WGET_OPTIONS=""
IMAGE_CATALOG="http://10.1.1.209/repos/bluedata"

# EPIC vars from AWS scripts
LOCAL_SSH_PUB_KEY_PATH="${OUT_DIR}/controller.pub_key"
LOCAL_SSH_PRV_KEY_PATH="${OUT_DIR}/controller.prv_key"
# Using default gateway device's IP (taking first interface on default gateway)
CLIENT_CIDR_BLOCK=$(ip a s dev $(ip route show default | head -1 | cut -d' ' -f5) | awk /'inet / { print $2 }')
VPC_CIDR_BLOCK=$CLIENT_CIDR_BLOCK
REGION=ME

# These are interfaces facing lab network
CREATE_EIP_CONTROLLER=False
# CTRL_PUB_IP=
# CTRL_PUB_HOST=
# CTRL_PUB_DNS=
CREATE_EIP_GATEWAY=False
# GATW_PUB_IP=$(echo "${CLIENT_CIDR_BLOCK}" | cut -d'/' -f1)
# GATW_PUB_HOST=ecp-virgo
# GATW_PUB_DNS="${GATW_PUB_HOST}.dlg.dubai"

INSTALL_WITH_SSL=True
CA_KEY="${OUT_DIR}/ca-key.pem"
CA_CERT="${OUT_DIR}/ca-cert.pem"

EPIC_DL_URL_NEEDS_PRESIGN=False
SELINUX_DISABLED=True
MAPR_CLUSTER1_COUNT=0
MAPR_CLUSTER2_COUNT=0
AD_SERVER_ENABLED=True
RDP_SERVER_ENABLED=False
RDP_SERVER_OPERATING_SYSTEM="LINUX"
CREATE_EIP_RDP_LINUX_SERVER=False

RUN_POST_CREATE=True

# Domainname for VMs
DOMAIN="ecp.demo"
# Virtual Network (will be created and deleted by these scripts)
VIRTUAL_NET_NAME="ecpnet"
NET=10.1.10 # Use this notation x.x.x (skip last dot as it will be added)
BRIDGE=virbr10

#TODO: Define in a user and script-friendly way

# Define VMs with resource mapping (gateway name conflicts with virbr dns name)
hosts=('controller' 'gw' 'host1' 'host2' 'host3')
cpus=(16 4 8 8 8)
mems=(65536 32768 65536 65536 65536)
## assign roles (for proper configuration script)
# possible roles: controller gateway worker ad rdp mapr1 mapr2
roles=('controller' 'gateway' 'worker' 'worker' 'worker')
# disk sizes (data disk size per host)
disks=(512 0 512 512 512)

if [ "${AD_SERVER_ENABLED}" == "True" ]; then
    hosts+=('ad')
    cpus+=(4)
    mems+=(8192)
    roles+=('ad')
    disks+=(0)
fi
