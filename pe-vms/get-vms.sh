#!/bin/bash

num_vms="$1"

if [[ -z "$num_vms" ]]; then
  num_vms=1
fi

for i in `seq ${num_vms}`; do
  echo "`floaty get redhat-7-x86_64 | jq '."redhat-7-x86_64"' | sed 's/"//g'`"
done
