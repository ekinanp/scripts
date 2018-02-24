#!/bin/bash

# Installs puppet agent on the given list of VMs
# using the value of MASTER_HOST as the puppet master.

master_vm="$1"
shift

if [[ -z "$master_vm" ]]; then
  echo "ERROR: no master found!"
  echo "USAGE: ./install-puppet-agent.sh <master-vm> ([<agent-vm>])*"
  exit 1
fi

site_manifest="/etc/puppetlabs/code/environments/production/manifests/site.pp"
for vm in "$@"; do
  ssh -t -oStrictHostKeyChecking=no root@$vm "curl -k https://${master_vm}:8140/packages/current/install.bash | sudo bash"
  echo ""
  echo "Going to sleep to wait for the agent cert to appear ..."
  sleep 10
  ssh -oStrictHostKeyChecking=no root@$master_vm "puppet cert sign ${vm}" 
  node_manifest=`echo "node \"'${vm}'\" {" && echo "  include cpp_dev_environment::facter_environment" && echo "}"`
  ssh -oStrictHostKeyChecking=no root@$master_vm "(echo '' && echo '${node_manifest}') >> ${site_manifest}"
done
