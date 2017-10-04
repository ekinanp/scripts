#!/bin/bash

# Installs puppet agent on the given list of VMs
# using the value of MASTER_HOST as the puppet master.

master_vm=`printenv MASTER_HOST`

if [[ -z "$master_vm" ]]; then
  echo "ERROR: no master found!"
  exit 1
fi

for vm in "$@"; do
  ssh -t -oStrictHostKeyChecking=no root@$vm "wget -O - -q --no-check-certificate --secure-protocol=TLSv1 https://${master_vm}:8140/packages/current/install.bash | sudo bash"
  ssh -oStrictHostKeyChecking=no root@$master_vm "puppet cert sign ${vm}" 
done
