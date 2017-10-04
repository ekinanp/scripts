#!/bin/bash

# Copies the available puppet tasks in ~/GitHub/orchestrator/dev-resources/tasks
# directory to the /opt/puppetlabs/pxp-agent/tasks directory of each given VM.
# Note that puppet agent must be installed on all of them (no checks will be done
# in this script for simplicity).
#
# Also copies all tasks to /etc/puppetlabs/code/environments/production/modules
# in the master
#
TASKS_ROOT=~/GitHub/orchestrator/dev-resources/tasks
AVAIL_TASKS=`find "${TASKS_ROOT}" -type d -depth 1`
MASTER_VM=`printenv MASTER_HOST`

for task in ${AVAIL_TASKS}; do
  scp -r -oStrictHostKeyChecking=no "$task" root@${MASTER_VM}:/etc/puppetlabs/code/environments/production/modules
done

for vm in "$@"; do
  for task in ${AVAIL_TASKS}; do
    ssh -t -oStrictHostKeyChecking=no root@$vm "mkdir /opt/puppetlabs/pxp-agent/tasks"
    scp -r -oStrictHostKeyChecking=no "$task" root@${vm}:/opt/puppetlabs/pxp-agent/tasks/
  done
done
