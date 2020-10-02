#!/usr/bin/env bash

source ./etc/kvm_config.sh

function get_ip_for_vm { 
    if [ $# -eq 1 ]; then 
        grep $1 "${HOSTS_FILE}" | cut -d" " -f2 
    fi
}

function get_role_for_vm {
    if [ $# -eq 1 ]; then 
        grep $1 "${HOSTS_FILE}" | cut -d" " -f3
    fi
}

function get_name_for_ip {
    if [ $# -eq 1 ]; then 
        grep $1 "${HOSTS_FILE}" | cut -d" " -f1
    fi
}

function create_vm {
    name=$1
    cpu=$2
    mem=$3
    role=$4
    disk=$5
    set +e
    vm=$(virsh dominfo $1)
    if [ "$?" -eq 0 ]; then
        echo "Reusing existing VM $1"
    else
        ./bin/kvm_deploy_centosvm.sh $name $cpu $mem $role $disk
        ip=$(get_ip_for_vm "${name}")
        sleep 30 # give time to start services

        # Upload local yum repo to all hosts
        # if [ ! -z ${LOCAL_YUM_REPO} ]; then
        #     ssh -o StrictHostKeyChecking=no -i "${LOCAL_SSH_PRV_KEY_PATH}" -T centos@${ip} "sudo yum-config-manager --add-repo ${LOCAL_YUM_REPO} && sudo yum-config-manager --disablerepo \* --enablerepo dlg\*"
        # fi
        # and update no_proxy
        if [ "${BEHIND_PROXY}" == "True" ]; then
            # Only update local host (variables.sh takes from system proxy file) and it is updated by kvm_set_proxy.sh on all hosts
            sudo sed -i "/^export no_proxy/ s/$/,${ip}/" ${SYSTEM_PROXY_FILE}
            # ssh -o StrictHostKeyChecking=no -i "${LOCAL_SSH_PRV_KEY_PATH}" -T centos@${ip} "sudo sed -i \"/export no_proxy/ s/$/,${ip}/\" ${SYSTEM_PROXY_FILE}"
        fi
    fi
    set -e
}

# Provide the VM name (domain in virsh) as argument
function destroy_vm {
    set +e 
    virsh dominfo "${1}" > /dev/null 2>&1
    if [ "$?" -eq 0 ]; then
        echo "Removing existing vm $1"
        sudo virsh destroy --domain "${1}" 
        sudo virsh undefine --domain "${1}"
        ip=$(get_ip_for_vm ${1})
        [ ! -z "${ip}" ] && sudo sed -i "s/,${ip}//g" ${SYSTEM_PROXY_FILE}
        sed -i "/^${1} /d" "${HOSTS_FILE}"
        # wait for VM to be gone - avoid open file errors
        sleep 1
    fi
    rm -rf "${VM_DIR}"/"${1}"/
    set -e
}

function create_network {
    set +e # Don't fail if network can't be found
    net_info=$(virsh net-info ${VIRTUAL_NET_NAME} 2>&1)
    if [ "$?" -eq 0 ]; then
        echo "Checking bridge name for match"
        if [[ $(echo $net_info | cut -d" " -f12) == ${BRIDGE} ]]; then
            echo "[INFO] Reusing existing network"
        else
            echo "[ERROR] Different bridge with same network name, delete/rename network and retry"
            exit 1
        fi
    else
        ./bin/kvm_prepare_network.sh
    fi
    set -e 
}

function destroy_network {
    set +e
    net_info=$(virsh net-info ${VIRTUAL_NET_NAME} 2>&1)
    if [ "$?" -eq 0 ]; then
        sudo virsh net-destroy ${VIRTUAL_NET_NAME}
        sudo virsh net-undefine ${VIRTUAL_NET_NAME}
        sudo rm -f /etc/NetworkManager/conf.d/localdns.conf
        sudo rm -f /etc/NetworkManager/dnsmasq.d/libvirt_dnsmasq.conf
    fi
    set -e
    # Remove added no_proxy configuration
    [ ! -z "$DOMAIN" ] && sudo sed -i "s+,.$DOMAIN++g" ${SYSTEM_PROXY_FILE}
    [ ! -z "$NET" ] && sudo sed -i "s+,$NET.0/24++g" ${SYSTEM_PROXY_FILE}

}
