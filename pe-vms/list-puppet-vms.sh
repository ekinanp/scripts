#!/bin/bash

num_vms="$1"

vms=`floaty list --active | sed '/Running[[:space:]]VMs:/d' | sed 's/^-[[:space:]]*\([^[:space:]]*\).*$/\1/g'`

for vm in $vms; do
  cmdres=`ssh -oStrictHostKeyChecking=no root@$vm "which puppet" 2>&1` 
  if [[ ! "$cmdres" =~ "no puppet" ]]; then
    echo "$vm"
  fi	
done
