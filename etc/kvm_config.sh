#!/usr/bin/env bash

# VM Network
DOMAIN="ecp.demo"
VIRTUAL_NET_NAME="ecpnet"
NET=10.1.4
BRIDGE=virbr4

# Gateway network
PUBLIC_DOMAIN=dlg.dubai
PUBLIC_BRIDGE="virbr20"
GATW_PUB_IP=10.1.1.22
GATW_PUB_HOST=ecpgw1
GATW_PUB_DNS="${GATW_PUB_HOST}.${PUBLIC_DOMAIN}"

# Host resources
hosts=('controller' 'gw' 'host1' 'host2' 'host3')
cpus=(16 8 16 16 12)
mems=(65536 32768 65536 65536 65536)
roles=('controller' 'gateway' 'worker' 'worker' 'worker')
disks=(512 0 512 512 512)
AD_SERVER_ENABLED=True
if [ "${AD_SERVER_ENABLED}" == "True" ]; then
    hosts+=('ad')
    cpus+=(4)
    mems+=(8192)
    roles+=('ad')
    disks+=(0)
fi

# Local settings
TIMEZONE="Asia/Dubai"
CENTOS_IMAGE_FILE=/files/CentOS-7-x86_64-GenericCloud-2003.qcow2
EPIC_FILENAME=hpe-cp-rhel-release-5.1-3011.bin
EPIC_DL_URL="ftp://ftp.dlg.dubai/${EPIC_FILENAME}"

# Airgap installation
BEHIND_PROXY=True
PROXY_URL="http://proxy.dlg.dubai:3128"
SYSTEM_PROXY_FILE="/etc/profile.d/proxy.sh"
NOPROXY=$(grep "^export no_proxy" ${SYSTEM_PROXY_FILE} | cut -d'=' -f2)

CREATE_EIP_CONTROLLER=False
CREATE_EIP_GATEWAY=True

INSTALL_WITH_SSL=True

PROJECT_DIR=/home/hpeadmin/hcp-demo-env-kvm-bash
VM_DIR="${PROJECT_DIR}"/vms
OUT_DIR="${PROJECT_DIR}"/generated
HOSTS_FILE="${OUT_DIR}"/hosts
CA_KEY="${OUT_DIR}/ca-key.pem"
CA_CERT="${OUT_DIR}/ca-cert.pem"
LOCAL_SSH_PUB_KEY_PATH="${OUT_DIR}/controller.pub_key"
LOCAL_SSH_PRV_KEY_PATH="${OUT_DIR}/controller.prv_key"

HOST_INTERFACE=$(ip route show default | head -1 | cut -d' ' -f5)
CLIENT_CIDR_BLOCK=$(ip a s dev ${HOST_INTERFACE} | awk /'inet / { print $2 }')
VPC_CIDR_BLOCK=$CLIENT_CIDR_BLOCK
REGION=ME
EPIC_OPTIONS='--skipeula'
WGET_OPTIONS=""

EPIC_DL_URL_NEEDS_PRESIGN=False
SELINUX_DISABLED=True
MAPR_CLUSTER1_COUNT=0 
MAPR_CLUSTER2_COUNT=0 
RDP_SERVER_ENABLED=False
RDP_SERVER_OPERATING_SYSTEM="LINUX"
CREATE_EIP_RDP_LINUX_SERVER=False

hostpart=$(echo ${PROXY_URL} | awk -F[/:] '{print $4}')
PROXY_IP=$(getent ahostsv4 $(echo $hostpart) | head -1 | cut -d' ' -f1)
PROXY_URL_WITH_IP=${PROXY_URL/${hostpart}/${PROXY_IP}}

