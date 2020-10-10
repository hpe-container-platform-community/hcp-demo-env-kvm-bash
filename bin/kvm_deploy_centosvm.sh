#!/usr/bin/env bash

# Get global vars 
source ./scripts/kvm_functions.sh
# source ./scripts/variables.sh

set -e # abort on error
set -u # abort on undefined variable
# Check arguments
if ! [ $# -eq 5 ]; then
    echo "Usage: $0 <vm-name> <cpu-count> <memoryGB> <role> <data-disksize>"
    exit 1
fi
# Number of virtual CPUs
CPUS=$2
# Amount of RAM in MB
MEM=$3
# Cloud init files
USER_DATA=user-data
META_DATA=meta-data
CI_ISO="${1}"-cidata.iso
# Disks
DISK1="${1}"-disk1.qcow2
DISK2="${1}"-disk2.qcow2
DISK3="${1}"-disk3.qcow2

echo $1 creating

# Remove if domain already exists
destroy_vm $1

mkdir -p "${VM_DIR}"/"${1}"
pushd "${VM_DIR}"/"${1}" > /dev/null
    # cloud-init config: set hostname, remove cloud-init package,
    # and add ssh-key 
    # SSH_KEY=$(<${PROJECT_DIR}/${LOCAL_SSH_PUB_KEY_PATH})
    cat > $USER_DATA <<EOF
#cloud-config

# Hostname management
preserve_hostname: False
hostname: ${1}
fqdn: ${1}.${DOMAIN}

# Configure where output will go
output: 
  all: ">> /var/log/cloud-init.log"

# configure interaction with ssh server
ssh_svcname: ssh
ssh_deletekeys: True
ssh_genkeytypes: ['rsa', 'ecdsa']

# Install public key for centos user
ssh_authorized_keys:
  - $(<${LOCAL_SSH_PUB_KEY_PATH})

# Remove cloud-init when finished with it
runcmd:
  - [ yum, -y, remove, cloud-init ]
  - echo "ip_resolve=4" >> /etc/yum.conf
  - hostnamectl set-hostname ${1}.${DOMAIN}
  - timedatectl set-timezone "${TIMEZONE}"
EOF

    echo "instance-id: $1; local-hostname: $1" > $META_DATA
    # Create CD-ROM ISO with cloud-init config
    # echo "$(date -R) Generating ISO for cloud-init..."
    genisoimage -output "${CI_ISO}" -volid cidata -joliet -r $USER_DATA $META_DATA
    # echo "$(date -R) Customizing and installing $1 ..."
    # Create and expand boot-disk "backed by centos cloud image"
    qemu-img create -f qcow2 -b "${CENTOS_IMAGE_FILE}" "${DISK1}" 
    qemu-img resize "${DISK1}" 512G 
    # Create persistent and ephemeral disks
    if [ $5 > 0 ]; then
      qemu-img create -f qcow2 $DISK2 ${5}G 
      qemu-img create -f qcow2 $DISK3 ${5}G 
    else # create dummy disks of 100M, should be removed later in the process #TODO
      qemu-img create -f qcow2 $DISK2 100M 
      qemu-img create -f qcow2 $DISK3 100M 
    fi

    # Give access so qemu can read disks
    sudo setfacl -m u:qemu:rx "${VM_DIR}"/"${1}"

    # add public interface if gateway
    public_int=""
    if [ "${1}" == "gw" ] && [ "${CREATE_EIP_GATEWAY}" == "True" ]; then
      public_int="--network bridge=${PUBLIC_BRIDGE},model=virtio"
    fi

    # Run installation (detached)
    sudo virt-install \
    --import \
    --name $1 \
    --memory $MEM \
    --vcpus $CPUS \
    --disk "${DISK1}",format=qcow2,bus=virtio \
    --disk "${DISK2}",format=qcow2,bus=virtio \
    --disk "${DISK3}",format=qcow2,bus=virtio \
    --disk "${CI_ISO}",device=cdrom \
    --network bridge="${BRIDGE}",model=virtio ${public_int} \
    --os-type Linux \
    --os-variant centos7.0 \
    --noautoconsole

    MAC=$(sudo virsh dumpxml $1 | awk -F\' '/mac address/ {print $2}' | head -n 1)
    
    echo -n "Waiting for IP "
    while true
    do
        IP=$(grep -B1 $MAC /var/lib/libvirt/dnsmasq/"${BRIDGE}".status | head \
             -n 1 | awk '{print $2}' | sed -e s/\"//g -e s/,//)
        if [ "$IP" = "" ]
        then
            sleep 1
            echo -n '.'
        else
            break
        fi
    done

    echo
    # Eject cdrom
    # echo "$(date -R) Cleaning up cloud-init..."
    sudo virsh change-media "${1}" sda --eject --config
    # Remove the unnecessary cloud init files
    sudo rm -f "${USER_DATA}" "${CI_ISO}"
    # Remove if data disk not needed
    if [ ${5} -eq 0 ]; then
      sudo virsh detach-disk --domain ${1} vdb --persistent --config --live
      sudo virsh detach-disk --domain ${1} vdc --persistent --config --live
    fi
    # Set to autostart with host
    sudo virsh autostart ${1}
    # Completed
    echo "$1 $IP $4" >> "${HOSTS_FILE}"

popd > /dev/null
