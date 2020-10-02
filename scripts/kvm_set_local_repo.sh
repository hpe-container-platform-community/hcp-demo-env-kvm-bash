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

while IFS= read -r host; do
    ip=$(echo ${host} | awk ' { print $2 } ' )
    echo "Setting local repo for ${ip}"
    centosrepo=$(cat <<EOF
[base]
name=CentOS-\$releasever - Base
baseurl=${LOCAL_YUM_REPO}/base/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#released updates
[updates]
name=CentOS-\$releasever - Updates
baseurl=${LOCAL_YUM_REPO}/updates/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that may be useful
[extras]
name=CentOS-\$releasever - Extras
baseurl=${LOCAL_YUM_REPO}/extras/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-\$releasever - Plus
baseurl=${LOCAL_YUM_REPO}/centosplus/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF
)

    ssh -o StrictHostKeyChecking=no -i "${LOCAL_SSH_PRV_KEY_PATH}" -T centos@${ip} <<EOF
echo "${centosrepo}" | sudo tee /etc/yum.repos.d/CentOS-Base.repo > /dev/null

EOF

done < ${HOSTS_FILE}
