#!/usr/bin/env bash

if ! [ $# -eq 2 ]; then
    echo "Usage: $0 <controller | gateway> <on | off>"
    exit 1
fi

source ./scripts/variables.sh

KVM_HOST_IP=$(echo ${CLIENT_CIDR_BLOCK} | cut -d'/' -f1)
if [[ "$1" == "controller" ]];then
    DEST_IP=${CTRL_PRV_IP}
else
    DEST_IP=${GATW_PRV_IP}
fi

if [[ "$2" == "on" ]]; then
    sudo /sbin/iptables -t nat -I PREROUTING -p tcp -d $KVM_HOST_IP --dport 80 -j DNAT --to-destination ${DEST_IP}:80
    sudo /sbin/iptables -t nat -I PREROUTING -p tcp -d $KVM_HOST_IP --dport 8080 -j DNAT --to-destination ${DEST_IP}:8080
    sudo /sbin/iptables -t nat -I PREROUTING -p tcp -d $KVM_HOST_IP --dport 443 -j DNAT --to-destination ${DEST_IP}:443
    sudo /sbin/iptables -t nat -I PREROUTING -p tcp -d $KVM_HOST_IP --dport 10000:11000 -j DNAT --to-destination ${DEST_IP}
    sudo /sbin/iptables -I FORWARD -m state -d ${DEST_IP}/24 --state NEW,RELATED,ESTABLISHED -j ACCEPT
    echo "Port forwarding for ${DEST_IP} on port 80/8080/443 enabled"
else
    # don't bother if rules dont exist
    set +e
    sudo /sbin/iptables -t nat -D PREROUTING -p tcp -d $KVM_HOST_IP --dport 80 -j DNAT --to-destination ${DEST_IP}:80
    sudo /sbin/iptables -t nat -D PREROUTING -p tcp -d $KVM_HOST_IP --dport 8080 -j DNAT --to-destination ${DEST_IP}:8080
    sudo /sbin/iptables -t nat -D PREROUTING -p tcp -d $KVM_HOST_IP --dport 443 -j DNAT --to-destination ${DEST_IP}:443
    sudo /sbin/iptables -t nat -D PREROUTING -p tcp -d $KVM_HOST_IP --dport 10000:11000 -j DNAT --to-destination ${DEST_IP}
    sudo /sbin/iptables -D FORWARD -m state -d ${DEST_IP}/24 --state NEW,RELATED,ESTABLISHED -j ACCEPT
    echo "Port forwarding for ${DEST_IP} on port 80/8080/443 disabled"
    set -e
fi

exit 0