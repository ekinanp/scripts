#!/usr/bin/env bash

SCRIPT_NAME="./scripts/run-beaker.sh"
HOSTS_NAME="hosts.cfg"

PE_VERSION=2017.3.2
PE_UPGRADE_VERSION=2018.1.0-rc8-2-g1d6b244

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

# Get the arguments
USAGE="${SCRIPT_NAME} <host-layout> [results-dir]"

host_layout="$1"
results_dir="$2"

[[ -z "${host_layout}" ]] && echo "${USAGE}" && exit 1
[[ -z "${results_dir}" ]] && results_dir=`generate_default_results_dir "${host_layout}"`

echo "Installing the relevant gems ..."

export BUNDLE_PATH=.bundle/gems
export BUNDLE_BIN=.bundle/bin
bundle install

echo ""
echo "Exporting the relevant environment variables ..."
setup_beaker_environment "${host_layout}" "${results_dir}"

echo ""
echo "Generating the hosts.cfg file ..."
mkdir -p ${results_dir}
hosts_cfg_content=`generate_hosts_config "${host_layout}"`

if [[ $? -ne 0 ]]; then
  echo ""
  echo "Failed to generate the hosts.cfg file. Clearing the results directory and exiting the script ..."
  rm -rf "${results_dir}"
  exit 1
fi

hosts_cfg="${results_dir}/${HOSTS_NAME}"
echo "${hosts_cfg_content}" > "${hosts_cfg}"

echo ""
echo "Running beaker ... "

run_beaker "${results_dir}" "${hosts_cfg}"

echo ""
echo "Finished running beaker. Copying the contents of the log directory to the results directory ..."
cp -r "${log_dir}/." "${results_dir}"
