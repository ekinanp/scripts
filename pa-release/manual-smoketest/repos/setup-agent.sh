#!/bin/bash

set -e

function on_host() {
  host="$1"
  cmd="$2"
  suppress="$3"

  if [[ -z "${suppress}" || "${suppress}" == "false" ]]; then
    ssh -oStrictHostKeyChecking=no root@${host} "${cmd} 2>&1" 2>/dev/null
  else
    ssh -oStrictHostKeyChecking=no root@${host} "${cmd} 2>&1" 2>/dev/null 1>/dev/null
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

echo "Running the script with the following master-agent pair ..."
echo "  MASTER: ${master_vm}"
echo "  AGENT: ${agent_vm}"
echo ""

echo "Running the script with the following package versions ..."
echo "  puppet-agent version: ${agent_version}"
echo ""

echo "STEP: Install the puppet-agent package"
master_ip=`on_master "facter ipaddress" | tail -n 1`
on_agent "echo ${master_ip} puppet >> /etc/hosts"
on_agent "rpm -Uvh http://yum.puppetlabs.com/puppet5/puppet5-release-el-7.noarch.rpm" 
on_agent "yum install -y puppet-agent-${agent_version}"
echo ""
echo ""

# Run puppet to create SSL keys and have master sign them.
echo "STEP: Run puppet to create SSL keys, and have master sign them."
set +e
on_agent "puppet agent -t"
set -e
echo "### DEBUG: Sleeping for 5 seconds to give some time for the agent cert to appear on the master ..."
sleep 5
on_master "puppet cert sign --all"
echo ""
echo ""

echo "STEP: Run puppet to get the catalog"
on_agent "puppet agent -t"
echo ""
echo ""

echo "Successfully set-up the agent VM!"
