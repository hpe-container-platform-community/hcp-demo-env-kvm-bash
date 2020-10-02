#!/usr/bin/env bash

###
# An attempt to reuse scripts from Chris Snow's repository
# https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform
###

set -e # abort on error
set -u # abort on undefined variable

source ./etc/kvm_config.sh

# Get scripts from github
pushd ./scripts > /dev/null
   [ ! -f functions.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/scripts/functions.sh
   if [ ! -f check_prerequisites.sh ]; then
      wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/scripts/check_prerequisites.sh
      # Hack to requirements check
      sed -i '/command -v terraform/,+5d' check_prerequisites.sh
      sed -i '/command -v aws/,+5d' check_prerequisites.sh
   fi
   [ ! -f bluedata_install.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/scripts/bluedata_install.sh
   [ ! -f post_refresh_or_apply.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/scripts/post_refresh_or_apply.sh
   [ ! -f mapr_install.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/scripts/mapr_install.sh
   [ ! -f mapr_update.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/scripts/mapr_update.sh
   [ ! -f verify_ad_server_config.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/scripts/verify_ad_server_config.sh
   chmod +x *.sh
   mkdir -p ad_files || true
   pushd ./ad_files > /dev/null
      [ ! -f ad_set_posix_classes.ldif ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/modules/module-ad-server/files/ad_set_posix_classes.ldif
      [ ! -f ad_user_setup.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/modules/module-ad-server/files/ad_user_setup.sh
      [ ! -f ldif_modify.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/modules/module-ad-server/files/ldif_modify.sh
      [ ! -f run_ad.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/modules/module-ad-server/files/run_ad.sh
      chmod +x *.sh
   popd > /dev/null
   mkdir -p end_user_scripts/embedded_mapr || true
   pushd end_user_scripts > /dev/null
      [ ! -f patch_datatap_5.1.1.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/scripts/end_user_scripts/patch_datatap_5.1.1.sh
      chmod +x *.sh
      pushd embedded_mapr > /dev/null
         [ ! -f 1_setup_epic_mapr_sssd.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/scripts/end_user_scripts/embedded_mapr/1_setup_epic_mapr_sssd.sh
         [ ! -f 2_setup_ubuntu_mapr_sssd_and_mapr_client.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/scripts/end_user_scripts/embedded_mapr/2_setup_ubuntu_mapr_sssd_and_mapr_client.sh
         [ ! -f 3_setup_datatap_5.0.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/scripts/end_user_scripts/embedded_mapr/3_setup_datatap_5.0.sh
         [ ! -f 3_setup_datatap_new.sh  ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/scripts/end_user_scripts/embedded_mapr/3_setup_datatap_new.sh
         chmod +x *.sh
      popd > /dev/null # embedded_mapr
      mkdir -p standalone_mapr || true
      pushd standalone_mapr > /dev/null 
         [ ! -f setup_datatap_5.1.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/scripts/end_user_scripts/standalone_mapr/setup_datatap_5.1.sh
         [ ! -f setup_ubuntu_mapr_sssd.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/scripts/end_user_scripts/standalone_mapr/setup_ubuntu_mapr_sssd.sh
         chmod +x *.sh
      popd > /dev/null # standalone_mapr
   popd > /dev/null # end_user_scripts
popd > /dev/null # scripts

pushd ./etc > /dev/null 
   if [ ${RUN_POST_CREATE} -a ! -f postcreate.sh ]; then
      wget -O postcreate.sh https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/etc/postcreate.sh_template
      # Replace ip forward/nat rules to use gateway instead of controller
      sed -i  "/.\/bin\/experimental\/02_gateway_add.sh/a .\/scripts\/kvm_ipforwarding.sh controller off\n.\/scripts\/kvm_ipforwarding.sh gateway on" postcreate.sh
      chmod +x *.sh
   fi
popd > /dev/null 

pushd ./bin > /dev/null
   [ ! -f df-cluster-acl-ad_admin1.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/bin/df-cluster-acl-ad_admin1.sh
   chmod +x *.sh
popd > /dev/null

mkdir -p ./bin/experimental || true
pushd ./bin/experimental > /dev/null 
   [ ! -f install_hpecp_cli.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/bin/experimental/install_hpecp_cli.sh
   [ ! -f 01_configure_global_active_directory.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/bin/experimental/01_configure_global_active_directory.sh
   [ ! -f 02_gateway_add.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/bin/experimental/02_gateway_add.sh
   # sed -i '/hpecp lock create/a hpecp lock list\nsleep 15\n' 02_gateway_add.sh
   if [ ! -f 03_k8sworkers_add.sh ]; then
      wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/bin/experimental/03_k8sworkers_add.sh
      # update disk definitions
      sudo sed -i 's/nvme1n1/vdb/g' 03_k8sworkers_add.sh
      sudo sed -i 's/nvme2n1/vdc/g' 03_k8sworkers_add.sh
   fi
   [ ! -f 04_k8scluster_create.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/bin/experimental/04_k8scluster_create.sh
   [ ! -f 05_kubedirector_spark_create.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/bin/experimental/05_kubedirector_spark_create.sh
   if [ ! -f epic_workers_add.sh ]; then
      wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/bin/experimental/epic_workers_add.sh
      # sed -i '/hpecp lock create/a hpecp lock list\nsleep 15\n' epic_workers_add.sh
      # update disk definitions
      sudo sed -i 's/nvme1n1/vdb/g' epic_workers_add.sh
      sudo sed -i 's/nvme2n1/vdc/g' epic_workers_add.sh
   fi
   [ ! -f epic_enable_virtual_node_assignment.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/bin/experimental/epic_enable_virtual_node_assignment.sh
   [ ! -f epic_spark24_cluster_deploy.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/bin/experimental/epic_spark24_cluster_deploy.sh
   [ ! -f set_gateway_ssl.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/bin/experimental/set_gateway_ssl.sh
   [ ! -f setup_demo_tenant_ad.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/bin/experimental/setup_demo_tenant_ad.sh
   [ ! -f epic_catalog_image_install_spark23.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/bin/experimental/epic_catalog_image_install_spark23.sh
   [ ! -f epic_catalog_image_install_spark24.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/bin/experimental/epic_catalog_image_install_spark24.sh
   [ ! -f epic_catalog_image_status.sh ] && wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/bin/experimental/epic_catalog_image_status.sh
   chmod +x *.sh
popd > /dev/null 

mkdir -p ./generated || true
pushd ./generated > /dev/null 
   if [ ! -f hpecp_cli_logging.conf ]; then
      wget https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/etc/hpecp_cli_logging.conf
      sed -i 's/${hpecp_cli_log_file}/.\/generated\/hpecp_cli.log/' hpecp_cli_logging.conf
   fi
   # Extract certificate keys
   [ ! -f bluedata_infra_variables.tf ] && wget "https://github.com/hpe-container-platform-community/hcp-demo-env-aws-terraform/raw/master/bluedata_infra_variables.tf"
   sed '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/!d;/-----END CERTIFICATE-----/q' bluedata_infra_variables.tf > ca-cert.pem
   sed '/-----BEGIN RSA PRIVATE KEY-----/,/-----END RSA PRIVATE KEY-----/!d;/-----END RSA PRIVATE KEY-----/q' bluedata_infra_variables.tf > ca-key.pem
   
popd > /dev/null 

### Update scripts 
printf "\nexit 0\n" >> ./scripts/end_user_scripts/embedded_mapr/2_setup_ubuntu_mapr_sssd_and_mapr_client.sh
printf "\nexit 0\n" >> ./scripts/post_refresh_or_apply.sh

# proxy hacks for scripts
function add_proxy {
   # sed -i -r 's/(sudo pip install --upgrade) (.*)/\1 --proxy \$PROXY_URL \2/' ./scripts/bluedata_install.sh
   # sed -i '/sudo yum install/i \\tgit config --global url.https://github.com/.insteadOf git://github.com/\n\tgit config --global --add http.proxy \$PROXY_URL\n\tgit config --global --add https.proxy \$PROXY_URL' ./bin/experimental/install_hpecp_cli.sh
   # sed -i -r 's/(pip install --upgrade) (.*)/\1 --proxy \$PROXY_URL \2/' ./bin/experimental/install_hpecp_cli.sh
   ## This is needed inside docker (need to check/verify if there's a better way)
   sed -i 's/wget https:/https_proxy=http:\/\/10.1.1.3:3128 wget https:/' ./scripts/end_user_scripts/embedded_mapr/3_setup_datatap_new.sh
}
function remove_proxy {
   echo "remove me"
   sed -i 's/https_proxy=http:\/\/10.1.1.3:3128 wget https:/wget https:/' ./scripts/end_user_scripts/embedded_mapr/3_setup_datatap_new.sh   
   # sed -i -r 's/(sudo pip install --upgrade --proxy \$PROXY_URL) (.*)/sudo pip install --upgrade \2/' ./scripts/bluedata_install.sh
   # sed -i '/\$PROXY_URL/d' ./bin/experimental/install_hpecp_cli.sh
   # sed -i '/.insteadOf/d' ./bin/experimental/install_hpecp_cli.sh
   # sed -i -r 's/(pip install --upgrade --proxy \$PROXY_URL) (.*)/pip install --upgrade \2/' ./bin/experimental/install_hpecp_cli.sh
   # if [ -f ./etc/postcreate.sh ]; then
   #    sed -i '/http_proxy/d' ./etc/postcreate.sh
   # fi
}

if [ "$BEHIND_PROXY" == "True" ]; then
   remove_proxy
   add_proxy
else
   remove_proxy
fi
