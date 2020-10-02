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
virsh net-define ${VIRTUAL_NET_XML_FILE}
virsh net-start ${VIRTUAL_NET_NAME}
virsh net-autostart ${VIRTUAL_NET_NAME}

# Enable IPv4 forwarding to/from virt-net
if [ $(grep -c "net.ipv4.ip.forward" /etc/sysctl.conf) = 0 ]; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo "net.ipv4.conf.all.forwarding=1" >> /etc/sysctl.conf
    # sysctl -p
fi

# Enable DNS resolution for virt-net
cat > /etc/NetworkManager/conf.d/${VIRTUAL_NET_NAME}.conf <<EOF
[main]
dns=dnsmasq
EOF

# Set bridge interface IP as DNS server for virt-net
cat > /etc/NetworkManager/dnsmasq.d/ecp_dnsmasq.conf <<EOF
server=/"${DOMAIN}"/${NET}.1
EOF

# Update no_proxy to skip this net
sudo sed -i "/^export no_proxy/ s/$/,.${DOMAIN},${NET}.0\/24/" ${SYSTEM_PROXY_FILE}

sudo systemctl restart NetworkManager

exit 0