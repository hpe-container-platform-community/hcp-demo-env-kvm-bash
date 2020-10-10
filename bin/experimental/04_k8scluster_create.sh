#!/bin/bash 

set -e
set -u

if [[ ! -d generated ]]; then
   echo "This file should be executed from the project directory"
   exit 1
fi

./scripts/check_prerequisites.sh
source ./scripts/variables.sh

pip3 install --quiet --upgrade --user hpecp

# use the project's HPECP CLI config file
export HPECP_CONFIG_FILE="./generated/hpecp.conf"

# Test CLI is able to connect
echo "Platform ID: $(hpecp license platform-id)"

AVAIL_K8S_WORKERS=($(hpecp k8sworker list --query "sort_by(@, &_links.self.href) | [?status == 'ready'][_links.self.href]" --output text))

K8S_WORKER_1=${AVAIL_K8S_WORKERS[0]}
K8S_WORKER_2=${AVAIL_K8S_WORKERS[1]}

if [[ "$K8S_WORKER_1" == "" ]] || [[ "$K8S_WORKER_2" == "" ]];
then 
   echo "Required two K8S workers, but could not find two."
   exit 1
else
   echo "Selecting first two available hosts: master='${K8S_WORKER_1}' and worker='${K8S_WORKER_2}'"
fi

K8S_VERSION=$(hpecp k8scluster k8s-supported-versions --major-filter 1 --minor-filter 17 --output text)

echo "Creating k8s cluster with version ${K8S_VERSION} and addons=[istio] | timeout=3600s"
CLUSTER_ID=$(hpecp k8scluster create --name c1 --k8s-version $K8S_VERSION --k8shosts-config "$K8S_WORKER_1:master,$K8S_WORKER_2:worker" --addons [istio])

echo "$CLUSTER_ID"

hpecp k8scluster wait-for-status --id $CLUSTER_ID --status [ready] --timeout-secs 3600
echo "K8S cluster created successfully - ID: ${CLUSTER_ID}"

echo "Adding addon [harbor] | timeout=1800s"
hpecp k8scluster add-addons --id $CLUSTER_ID --addons [harbor]
hpecp k8scluster wait-for-status --id $CLUSTER_ID --status [ready] --timeout-secs 1800
echo "Addon successfully added"

echo "Creating tenant"
TENANT_ID=$(hpecp tenant create --name "k8s-tenant-1" --description "dev tenant" --k8s-cluster-id $CLUSTER_ID  --tenant-type k8s)
hpecp tenant wait-for-status --id $TENANT_ID --status [ready] --timeout-secs 1800
echo "K8S tenant created successfully - ID: ${TENANT_ID}"

ADMIN_GROUP="CN=DemoTenantAdmins,CN=Users,DC=samdom,DC=example,DC=com"
ADMIN_ROLE=$(hpecp role list  --query "[?label.name == 'Admin'][_links.self.href] | [0][0]" --output json | tr -d '"')
hpecp tenant add-external-user-group --tenant-id "$TENANT_ID" --group "$ADMIN_GROUP" --role-id "$ADMIN_ROLE"

MEMBER_GROUP="CN=DemoTenantUsers,CN=Users,DC=samdom,DC=example,DC=com"
MEMBER_ROLE=$(hpecp role list  --query "[?label.name == 'Member'][_links.self.href] | [0][0]" --output json | tr -d '"')
hpecp tenant add-external-user-group --tenant-id "$TENANT_ID" --group "$MEMBER_GROUP" --role-id "$MEMBER_ROLE"

echo "Configured tenant with AD groups Admins=DemoTenantAdmins... and Members=DemoTenantUsers..."
