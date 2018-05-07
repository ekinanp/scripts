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
  export BEAKER_HOSTGENERATOR_VERSION="~> 1"
  export BEAKER_HOSTS="${results_dir}/${HOSTS_NAME}"
  export ABS_RESOURCE_HOSTS=`get-abs-resources "${host_layout}"`
  export SERVER_VERSION=6.0.0.master.SNAPSHOT.2018.04.15T2216
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
