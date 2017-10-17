#!/bin/bash

num_vms="$1"

if [[ -z "$num_vms" ]]; then
  num_vms=1
fi

master_vm=`printenv MASTER_HOST`

if [[ -z "$master_vm" ]]; then
  echo "ERROR: Must have a master VM to install the agent on !"
  echo "Set the MASTER_HOST environment variable to the VM serving as the puppet master!"
  exit 1
fi

agent_vms=`./get-vms.sh ${num_vms}`
./install-puppet-agent.sh $agent_vms
