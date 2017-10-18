#!/usr/bin/env bash

# TODO: Fill me in!
# This is a template script for doing a beaker run.

SCRIPT_NAME="./scripts/run-beaker.sh"
HOSTS_NAME="hosts.cfg"

# This should take in the host layout as a parameter
generate_default_results_dir() {
  local host_layout = "$1"
}

# This should take in the host layout and results directory as parameters
setup_beaker_environment() {
  local host_layout = "$1"
  local results_dir = "$2"

  # TODO: Setup environment variables here!
}

# This should take in the host layout and output the contents of the hosts.cfg
# file
generate_hosts_config() {
  local host_layout = "$1"

  # TODO: Generate the hosts.cfg file's contents here
}

# This should take in the results directory and the generated hosts.cfg
# file, and then proceed to run beaker (either as a rake task, or the command
# itself, directly).
#
# It should set a variable named "log_dir" pointing to the path of the log directory
# containing the results of the run.
#
# The last line should contain the path to the log directory containing the
# results of the run.
run_beaker() {
  local results_dir = "$1"
  local hosts_cfg = "$2"

  # TODO: Run beaker, then set the path of the log directory
}

# THIS PART SHOULD BE DISPLAYED!

# Get the arguments
USAGE="${SCRIPT_NAME} <host-layout> [results-dir]"

host_layout="$1"
results_dir="$2"

[[ -z "$host_layout" ]] && echo "$USAGE" && exit 1
[[ -z "$results_dir" ]] && results_dir=`generate_default_results_dir "${host_layout}"`

echo "Installing the relevant gems ..."
bundle install

echo ""
echo "Exporting the relevant environment variables ..."
setup_beaker_environment "${host_layout}" "${results_dir}"

echo ""
echo "Generating the hosts.cfg file ..."
mkdir -p $results_dir
hosts_cfg_content=`generate_hosts_config "${host_layout}"`

if [[ $? -ne 0 ]]; then
  echo ""
  echo "Failed to generate the hosts.cfg file. Clearing the results directory and exiting the script ..."
  rm -rf "$results_dir"
  exit 1
fi

hosts_cfg="${results_dir}/${HOSTS_NAME}"
echo "$hosts_cfg_content" > "$hosts_cfg"

echo ""
echo "Running beaker ... "

run_beaker "${hosts_cfg}" "${results_dir}" 

echo "Finished running beaker. Copying the contents of the log directory to the results directory ..."
cp -r "${log_dir}" "${results_dir}"
