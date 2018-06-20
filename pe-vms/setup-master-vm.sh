#!/bin/bash

master_vm="$1"

if [[ -z "$master_vm" ]]; then
  echo "ERROR: Need to specify a master VM host!"
  exit 1
fi

set -e
./install-puppet-enterprise.sh "$master_vm"
sed -i -e "s/export MASTER_HOST=.*/export MASTER_HOST=${master_vm}/" ~/.bash_profile 
"./create-puppet-token.sh" "${master_vm}"

## Set-up some git stuff
#ssh -oStrictHostKeyChecking=no root@$master_vm "yum install -y git vim" 
#
## Clone relevant modules. See if there's a way to use bolt with this
#MODULES="ekinanp/cpp_dev_environment"
#modules_root="/etc/puppetlabs/code/environments/production/modules/"
#for module in ${MODULES}; do
#  ssh -oStrictHostKeyChecking=no root@$master_vm "git clone https://github.com/${module}" 
#  dir=`echo "${module}" | gawk -F "/" {'print $2'}`
#  ssh -oStrictHostKeyChecking=no root@$master_vm "rm -rf "${modules_root}/${dir}" && mv ${dir} ${modules_root}" 
#done
