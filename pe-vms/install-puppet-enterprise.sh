#!/bin/bash

usage="Usage: $0 <vm-host>"

vm_host="$1"

if [[ -z "$vm_host" ]]; then
  echo "ERROR: vm host not specified!"
  echo "$usage"
  exit 1
fi

PUPPET_INST_DIR="puppet-enterprise-2018.1.0-rc12-23-g245d08c-el-7-x86_64"
PUPPET_TAR=${PUPPET_INST_DIR}.tar

ssh-add &> /dev/null

ssh -oStrictHostKeyChecking=no root@$vm_host 'yum install -y ntp wget && ntpdate pool.ntp.org' 
ssh -oStrictHostKeyChecking=no root@$vm_host "wget http://neptune.puppetlabs.lan/2018.1/ci-ready/${PUPPET_TAR}"
ssh -oStrictHostKeyChecking=no root@$vm_host "tar xf ${PUPPET_TAR}" 
ssh -oStrictHostKeyChecking=no root@$vm_host "cd ${PUPPET_INST_DIR} && ./puppet-enterprise-installer" 
