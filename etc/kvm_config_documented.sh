#!/usr/bin/env bash

# Top Level Directory for the project - all scripts should run at here
PROJECT_DIR=/home/hpeadmin/hcp-demo-env-kvm-bash
# Where to store VMs, need to provide access to qemu user in selinux context (see README#FAQ)
VM_DIR="${PROJECT_DIR}"/vms
# Output files for the project - you'll find everything you need to connect to ECP here
OUT_DIR="${PROJECT_DIR}"/generated
# Deployed hosts are tracked here - format: "hostname - IP address - role"
HOSTS_FILE=${OUT_DIR}/hosts
# Backing file image for VMs (CentOS-7-x86_64-GenericCloud-2003.qcow2)
#you'll need to provide access to qemu user in selinux context
CENTOS_IMAGE_FILE=/files/CentOS-7-x86_64-GenericCloud-2003.qcow2
# Environment settings
BEHIND_PROXY=True
PROXY_URL="http://proxy.dlg.dubai:3128"
# Local repository for yum installs
LOCAL_REPO_FILE="http://www.dlg.dubai/repos/dlg.repo"
# Binary file for installer
EPIC_FILENAME=hpe-cp-rhel-release-5.1-3011.bin
EPIC_DL_URL="ftp://ftp.dlg.dubai/${EPIC_FILENAME}"
# To be used/updated if BEHIND_PROXY
EPIC_OPTIONS='--skipeula'
WGET_OPTIONS=""
IMAGE_CATALOG="http://www.dlg.dubai/repos/bluedata"

# Update access for local network (otherwise ECP will be accessible only within host machine)
CREATE_EIP_CONTROLLER=False

CREATE_EIP_GATEWAY=True
PUBLIC_DOMAIN=dlg.dubai
PUBLIC_BRIDGE="virbr20" # this should exist on host (https://lukas.zapletalovi.com/2015/09/fedora-22-libvirt-with-bridge.html)
GATW_PUB_IP=10.1.1.22
GATW_PUB_HOST=ecpgw1
GATW_PUB_DNS="${GATW_PUB_HOST}.${PUBLIC_DOMAIN}"

INSTALL_WITH_SSL=True

# Rest of the variables from AWS scripts
CA_KEY="${OUT_DIR}/ca-key.pem"
CA_CERT="${OUT_DIR}/ca-cert.pem"
LOCAL_SSH_PUB_KEY_PATH="${OUT_DIR}/controller.pub_key"
LOCAL_SSH_PRV_KEY_PATH="${OUT_DIR}/controller.prv_key"
# Using default gateway device's IP (taking first interface on default gateway)
HOST_INTERFACE=$(ip route show default | head -1 | cut -d' ' -f5)
CLIENT_CIDR_BLOCK=$(ip a s dev ${HOST_INTERFACE} | awk /'inet / { print $2 }')
VPC_CIDR_BLOCK=$CLIENT_CIDR_BLOCK
# Not used
REGION=ME

EPIC_DL_URL_NEEDS_PRESIGN=False
SELINUX_DISABLED=True
MAPR_CLUSTER1_COUNT=0 # Either 0 or 3
MAPR_CLUSTER2_COUNT=0 # Either 0 or 3
AD_SERVER_ENABLED=True
RDP_SERVER_ENABLED=False
RDP_SERVER_OPERATING_SYSTEM="LINUX"
CREATE_EIP_RDP_LINUX_SERVER=False

RUN_POST_CREATE=True # TODO: should be removed and rely on file being in /etc/postcreate.sh, it is run if it is there

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

# Set your timezone
TIMEZONE="Asia/Dubai"

# Calculated
# Convert proxy_url to ip (mainly for containers)
hostpart=$(echo ${PROXY_URL} | awk -F[/:] '{print $4}')
PROXY_IP=$(getent ahostsv4 $(echo $hostpart) | head -1 | cut -d' ' -f1)
PROXY_URL_WITH_IP=${PROXY_URL/${hostpart}/${PROXY_IP}}
# Initialize with local host's no_proxy
SYSTEM_PROXY_FILE="/etc/profile.d/proxy.sh"
NOPROXY=$(grep "^export no_proxy" ${SYSTEM_PROXY_FILE} | cut -d'=' -f2)
