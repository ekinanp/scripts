#!/bin/bash

set -e

function on_host() {
  host="$1"
  cmd="$2"
  suppress="$3"

  if [[ -z "${suppress}" || "${suppress}" == "false" ]]; then
    ssh -oStrictHostKeyChecking=no root@${host} "${cmd}" 2>/dev/null
  else
    ssh -oStrictHostKeyChecking=no root@${host} "${cmd}" 2>/dev/null 1>/dev/null
  fi
}

function on_master() {
  cmd="$1"
  suppress="$2"

  echo ""
  echo "### DEBUG: Running the following command on the master"
  echo "  ${cmd}"
  echo "###"
  on_host ${master_vm} "${cmd}" "${suppress}"
}

function on_agent() {
  cmd="$1"
  suppress="$2"

  echo ""
  echo "### DEBUG: Running the following command on the agent"
  echo "  ${cmd}"
  echo "###"
  on_host ${agent_vm} "${cmd}" "${suppress}"
}

USAGE="USAGE: $0 <master-vm> <agent-vm> <agent-version>"

master_vm="$1"
agent_vm="$2"
agent_version="$3"

if [[ -z "${master_vm}" || -z "${agent_vm}" || -z "${agent_version}" ]]; then
  echo "${USAGE}"
  exit 1
fi

echo "Running the script with the following package versions ..."
echo "  puppet-agent version: ${agent_version}"
echo ""

## PUPPET AGENT

# Install puppet-agent package
echo "STEP (1): Install the puppet-agent package"
master_ip=`on_master "facter ipaddress" | tail -n 1`
on_agent "echo ${master_ip} puppet >> /etc/hosts"
on_agent "curl -O http://builds.puppetlabs.lan/puppet-agent/${agent_version}/artifacts/el/7/PC1/x86_64/puppet-agent-${agent_version}-1.el7.x86_64.rpm"
on_agent "rpm -ivh puppet-agent-${agent_version}-1.el7.x86_64.rpm"
echo ""
echo ""

# Run puppet to create SSL keys and have master sign them.
echo "STEP (2): Run puppet to create SSL keys, and have master sign them."
set +e
on_agent "puppet agent -t"
set -e
echo "### DEBUG: Sleeping for 5 seconds to give master some time for the agent cert to appear ..."
sleep 5
on_master "puppet cert sign --all"
echo ""
echo ""

echo "STEP (3): Run puppet to get the catalog"
on_agent "puppet agent -t"
echo ""
echo ""

echo "Successfully set-up the agent VM!"
