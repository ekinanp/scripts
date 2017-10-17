#!/bin/bash

# Extends the given list of VMs lifetime by 168 hours (7 days)

for vm in "$@"; do
  prefix=`echo -n $vm | sed 's/\([^\.]*\).*/\1/'`
  cur_lifetime=`floaty query $vm | sed 's/=>/:/g' | jq .\"${prefix}\"."lifetime"`
  floaty modify "$vm" --lifetime $((cur_lifetime + 168))
done
