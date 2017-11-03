#!/bin/bash

vm=`./get-vms.sh`

set -e
./install-puppet-enterprise.sh "$vm"
sed -i -e "s/export MASTER_HOST=.*/export MASTER_HOST=${vm}/" ~/.bash_profile 
"./create-puppet-token.sh" "${vm}"

