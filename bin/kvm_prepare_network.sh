#!/usr/bin/env bash

source "./scripts/kvm_functions.sh"

# Define network settings
VIRTUAL_NET_XML_FILE=$(mktemp)
trap '{ rm -f $VIRTUAL_NET_XML_FILE; }' EXIT
cat > ${VIRTUAL_NET_XML_FILE} <<- EOB
<network>
    <name>${VIRTUAL_NET_NAME}</name>
    <bridge name='${BRIDGE}' stp='on' delay='0'/>
    <forward mode="nat"/>
        <ip address="${NET}.1" netmask="255.255.255.0">
            <dhcp>
                <range start="${NET}.2" end="${NET}.254"/>
            </dhcp>
        </ip>
    <domain name='${DOMAIN}' localOnly='yes'/>
</network>
EOB

# Create network
sudo virsh net-define ${VIRTUAL_NET_XML_FILE}
sudo virsh net-start ${VIRTUAL_NET_NAME}
sudo virsh net-autostart ${VIRTUAL_NET_NAME}
echo "allow all" | sudo tee /etc/qemu-kvm/${USER}.conf > /dev/null
echo "include /etc/qemu-kvm/${USER}.conf" | sudo tee --append /etc/qemu-kvm/bridge.conf
sudo chown root:${USER} /etc/qemu-kvm/${USER}.conf
sudo chmod 640 /etc/qemu-kvm/${USER}.conf

# Enable IPv4 forwarding to/from virt-net
if [ $(grep -c "net.ipv4.ip.forward" /etc/sysctl.conf) = 0 ]; then
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv4.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.conf
    # sysctl -p
fi

# Enable DNS resolution for virt-net
netmanconf=$(cat <<EOF
[main]
dns=dnsmasq
EOF
)

echo "${netmanconf}" | sudo tee /etc/NetworkManager/conf.d/localdns.conf > /dev/null

# Set bridge interface IP as DNS server for virt-net
dnsmasqconf=$(cat <<EOF
server=/"${DOMAIN}"/${NET}.1
EOF
)
echo "${dnsmasqconf}" | sudo tee /etc/NetworkManager/dnsmasq.d/libvirt_dnsmasq.conf > /dev/null

# Update no_proxy to skip this net
sudo sed -i "/^export no_proxy/ s/$/,.${DOMAIN},${NET}.0\/24/" ${SYSTEM_PROXY_FILE}

# Setup bridged/routed network for gateway
if [ "${CREATE_EIP_GATEWAY}" == "True" ]; then
    cat > ${VIRTUAL_NET_XML_FILE} <<- EOB
<network>
    <name>${LOCAL_NET_NAME}</name>
    <forward mode="bridge" >
        <interface dev='${LOCAL_NET_DEVICE}'/>
    </forward>
</network>
EOB
    sudo virsh net-define ${VIRTUAL_NET_XML_FILE}
    sudo virsh net-start ${LOCAL_NET_NAME}
    sudo virsh net-autostart ${LOCAL_NET_NAME}

fi

sudo systemctl restart NetworkManager

exit 0