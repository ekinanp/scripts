#!/usr/bin/env bash

SCRIPT_NAME="./run-beaker.sh"
HOSTS_NAME="hosts.yaml"

# This should take in the host layout as a parameter and generate
# the default results directory on STDOUT
generate_default_results_dir() {
  local host_layout="$1"

  echo "runs/${host_layout}"
}

# This should take in the host layout and results directory as parameters
# and setup the beaker environment
setup_beaker_environment() {
  local host_layout="$1"
  local results_dir="$2"

  export SHA=13c871dca163d15c9af23e143666f37919a0e62e
  export GEM_SOURCE="http://rubygems.delivery.puppetlabs.net"
  export BEAKER_VERSION="git://github.com/puppetlabs/beaker#master"
  export BEAKER_HOSTGENERATOR_VERSION="~> 1"
  export BEAKER_HOSTS="${results_dir}/${HOSTS_NAME}"
  export RELEASE_STREAM="puppet6"
}

# This should take in the host layout and output the contents of the hosts.cfg
# file
generate_hosts_config() {
  local host_layout="$1"

  bundle exec beaker-hostgenerator "${host_layout}" --hypervisor abs --disable-default-role --osinfo-version 1
}

# This should take in the results directory and the generated hosts.cfg
# file, and then proceed to run beaker (either as a rake task, or the command
# itself, directly).
#
# It should set a variable named "log_dir" pointing to the path of the log directory
# containing the results of the run.
run_beaker() {
  local results_dir="$1"
  local hosts_cfg="$2"

  bundle exec rake ci:test:aio

  log_dir="log/${results_dir}"
  log_dir="${log_dir}/`ls ${log_dir}`"
}

# Get the arguments
USAGE="${SCRIPT_NAME} <host-layout> [results-dir]"

host_layout="$1"
results_dir="$2"

[[ -z "${host_layout}" ]] && echo "${USAGE}" && exit 1
[[ -z "${results_dir}" ]] && results_dir=`generate_default_results_dir "${host_layout}"`

echo ""
echo "Exporting the relevant environment variables ..."
setup_beaker_environment "${host_layout}" "${results_dir}"

echo "Installing the relevant gems ..."
export BUNDLE_PATH=.bundle/gems
export BUNDLE_BIN=.bundle/bin
bundle install

echo ""
echo "Generating the hosts.cfg file ..."
mkdir -p ${results_dir}
hosts_cfg_content=`generate_hosts_config "${host_layout}"`

export ABS_RESOURCE_HOSTS=`get-abs-resources "${host_layout}"`

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
