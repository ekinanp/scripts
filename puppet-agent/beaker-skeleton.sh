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

  export SHA=7393c9d21f9acad7406eb0c26a4cc40e8b340f53
  export SUITE_VERSION=1.10.8.66.g7393c9d
  export BEAKER_HOSTS="${results_dir}/${HOSTS_NAME}"
  export TESTS=tests/validate_vendored_ruby.rb
  export OPTIONS='--test-tag-exclude=server'
  export ABS_RESOURCE_HOSTS=`get-abs-resources "${host_layout}"`
  export SERVER_VERSION=2.8.0
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

  bundle exec rake acceptance:development

  log_dir="log/${results_dir}"
  log_dir="${log_dir}/`ls ${log_dir}`"
}
