#!/usr/bin/env bash

source "./scripts/variables.sh"

ssh -o StrictHostKeyChecking=no -i "${LOCAL_SSH_PRV_KEY_PATH}" -T centos@${CTRL_PUB_IP} << ENDSSH
sudo wget --no-proxy -e dotbytes=10M -c -nd -np --no-clobber -P /srv/bluedata/catalog ${IMAGE_CATALOG}/bdcatalog-centos7-bluedata-spark231juphub7xssl-3.4.bin
sudo wget --no-proxy -e dotbytes=10M -c -nd -np --no-clobber -P /srv/bluedata/catalog ${IMAGE_CATALOG}/bdcatalog-centos7-bluedata-spark240juphub7xssl-2.8.bin
sudo chmod 750 /srv/bluedata/catalog/*
sudo chown apache:apache /srv/bluedata/catalog/*
sudo restorecon /srv/bluedata/catalog/
sudo systemctl restart bds-controller
ENDSSH

# export HPECP_CONFIG_FILE="./generated/hpecp.conf"

# # Test CLI is able to connect
# echo "Platform ID: $(hpecp license platform-id)"
