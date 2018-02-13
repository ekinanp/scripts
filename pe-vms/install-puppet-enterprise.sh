#!/bin/bash

usage="Usage: $0 <vm-host>"

vm_host="$1"

if [[ -z "$vm_host" ]]; then
  echo "ERROR: vm host not specified!"
  echo "$usage"
  exit 1
fi

PUPPET_INST_DIR=puppet-enterprise-2017.3.4-el-7-x86_64
PUPPET_TAR=${PUPPET_INST_DIR}.tar

ssh-add &> /dev/null

ssh -oStrictHostKeyChecking=no root@$vm_host 'yum install -y ntp wget && ntpdate pool.ntp.org' 
ssh -oStrictHostKeyChecking=no root@$vm_host "wget http://neptune.puppetlabs.lan/2017.3/ci-ready/${PUPPET_TAR}"
ssh -oStrictHostKeyChecking=no root@$vm_host "tar xf ${PUPPET_TAR}" 
ssh -oStrictHostKeyChecking=no root@$vm_host "cd ${PUPPET_INST_DIR} && ./puppet-enterprise-installer" 
