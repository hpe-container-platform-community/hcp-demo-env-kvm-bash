#!/usr/bin/env bash

set -e # abort on error
set -u # abort on undefined variable

source "scripts/variables.sh"

# Skip if not running behind a proxy
[ ! "${BEHIND_PROXY}" == "True" ] && exit 0

# echo "Setting proxy for all hosts" 
# echo "http/https proxy: ${PROXY_URL}"
# echo "no_proxy: ${NOPROXY}"
# echo "Gateway DNS Name: ${GATW_PRV_DNS}"

echo "No proxy set to: ${NOPROXY}"

while IFS= read -r host; do
    ip=$(echo ${host} | awk ' { print $2 } ' )
    echo "Updating ${ip} for proxy settings"

    proxy_sh=$(cat <<EOF
export http_proxy=${PROXY_URL_WITH_IP}
export https_proxy=${PROXY_URL_WITH_IP}
export ftp_proxy=${PROXY_URL_WITH_IP}
export no_proxy=${NOPROXY}
# For curl
export HTTP_PROXY=${PROXY_URL_WITH_IP}
export HTTPS_PROXY=${PROXY_URL_WITH_IP}
export FTP_PROXY=${PROXY_URL_WITH_IP}
export NO_PROXY=${NOPROXY}
EOF
)

    docker_proxy=$(cat <<EOF
[Service]
Environment="HTTP_PROXY=${PROXY_URL_WITH_IP}"
Environment="HTTPS_PROXY=${PROXY_URL_WITH_IP}"
Environment="NO_PROXY=${NOPROXY}"
EOF
)

    docker_conf=$(cat <<EOF
{
    "proxies":
    {
    "default":
    {
        "httpProxy": "${PROXY_URL_WITH_IP}",
        "httpsProxy": "${PROXY_URL_WITH_IP}",
        "noProxy": "${NOPROXY}"
    }
    }
}
EOF
)

    wgetrc=$(cat <<EOF
use_proxy=on
http_proxy=${PROXY_URL_WITH_IP}
https_proxy=${PROXY_URL_WITH_IP}
EOF
)

    gitconf=$(cat <<EOF
[http]
        proxy = "${PROXY_URL_WITH_IP}"
[https]
        proxy = "${PROXY_URL_WITH_IP}"
[url \"https://github.com/\"]
        insteadOf = git://github.com/
EOF
)

    pipconf=$(cat <<EOF
[global]
proxy="${PROXY_URL_WITH_IP}"
EOF
)

    ssh -o StrictHostKeyChecking=no -i "${LOCAL_SSH_PRV_KEY_PATH}" -T centos@${ip} <<EOF
grep "proxy=" /etc/yum.conf > /dev/null || echo "proxy=${PROXY_URL_WITH_IP}" | sudo tee -a /etc/yum.conf > /dev/null
echo "${proxy_sh}" | sudo tee ${SYSTEM_PROXY_FILE} > /dev/null
sudo mkdir -p /etc/systemd/system/docker.service.d/ > /dev/null
echo "${docker_proxy}" | sudo tee /etc/systemd/system/docker.service.d/docker-proxy.conf > /dev/null
echo "${docker_conf}" | sudo tee /etc/default/docker > /dev/null
grep "proxy=" /etc/wgetrc > /dev/null || echo "${wgetrc}" | sudo tee -a /etc/wgetrc > /dev/null
echo "${gitconf}" | sudo tee /etc/gitconfig > /dev/null
echo "${pipconf}" | sudo tee /etc/pip.conf > /dev/null
sudo sed -i 's/^enabled=1/enabled=0/' /etc/yum/pluginconf.d/fastestmirror.conf
sudo yum install -y deltarpm

EOF

done < ${HOSTS_FILE}
