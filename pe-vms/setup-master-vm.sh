#!/bin/bash

vm=`./get-vms.sh`

set -e
./install-puppet-enterprise.sh "$vm"
./update-orch.sh "$vm"
