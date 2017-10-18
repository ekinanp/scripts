#!/usr/bin/env bash

SCRIPT_NAME="./scripts/run-beaker.sh"
HOSTS_NAME="hosts.cfg"

# This should take in the host layout as a parameter and generate
# the default results directory on STDOUT
generate_default_results_dir() {
  local host_layout="$1"
}

# This should take in the host layout and results directory as parameters
# and setup the beaker environment
setup_beaker_environment() {
  local host_layout="$1"
  local results_dir="$2"
}

# This should take in the host layout and output the contents of the hosts.cfg
# file
generate_hosts_config() {
  local host_layout="$1"
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
}
