#!/usr/bin/env bash

SCRIPT_NAME="./scripts/run-beaker.sh"
HOSTS_NAME="hosts.cfg"

PE_VERSION=2017.3.0
PE_UPGRADE_VERSION=2017.3.2-rc1-91-g04812f7

generate_default_results_dir() {
  local host_layout="$1"

  echo "runs/${host_layout}_${PE_VERSION}_${PE_UPGRADE_VERSION}"
}

setup_beaker_environment() {
  local host_layout="$1"
  local results_dir="$2"

  export BEAKER_KEYFILE=~/.ssh/id_rsa-acceptance
  export BEAKER_HELPER=lib/beaker_helper.rb
  export BEAKER_PRESUITE=setup/install.rb,setup/agent_upgrade.rb
  export BEAKER_TESTSUITE=acceptance/tests
  export BEAKER_PRECLEANUP=acceptance/post
  export ABS_RESOURCE_HOSTS=`get-abs-resources "${host_layout}"`
  export pe_version="$PE_VERSION"
  export pe_upgrade_version="$PE_UPGRADE_VERSION"
}

generate_hosts_config() {
  local host_layout="$1"

  bundle exec beaker-hostgenerator "${host_layout}" --hypervisor abs
}

run_beaker() {
  local results_dir="$1"
  local hosts_cfg="$2"

  # TODO: Run beaker, then set the path of the log directory
  bundle exec beaker --hosts ${hosts_cfg} --type pe --keyfile ${BEAKER_KEYFILE} --tests ${BEAKER_TESTSUITE} --preserve-hosts onfail --helper ${BEAKER_HELPER} --pre-cleanup ${BEAKER_PRECLEANUP} --pre-suite ${BEAKER_PRESUITE} --log-prefix ${results_dir} --log-level verbose --fail-mode fast

  log_dir="log/${results_dir}"
  log_dir="${log_dir}/`ls ${log_dir}`"
}
