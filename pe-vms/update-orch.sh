#!/bin/bash

usage="Usage: $0 <vm-host>"

vm_host="$1"

if [[ -z "$vm_host" ]]; then
  echo "ERROR: vm host not specified!"
  echo "$usage"
  exit 1
fi

sed -i -e "s/export MASTER_HOST=.*/export MASTER_HOST=${vm_host}/" ~/.bash_profile 
"./create-puppet-token.sh" "${vm_host}"

export MASTER_HOST="${vm_host}"

# update orch-service
cd ~/GitHub/orchestrator
./scripts/cert-stealer.sh

# update orch-client
cd ~/GitHub/orchestrator-client
./connect-to.sh "${vm_host}"
