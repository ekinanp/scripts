#!/usr/bin/env bash

# Useful routines
echoln() {
  echo ""
  echo "$1"
}

cleanup() {
  for dir in "$results_dir" "$log_dir"; do
    if [[ -n "$dir" ]]; then
      rm -rf "$dir"
    fi
  done
  trap - SIGINT SIGTERM
  kill -- -$$
}

# Get the arguments
USAGE="./scripts/run-beaker.sh <host-layout> <n> [results-dir]"

#PE_VERSION=2016.1.2
#PE_UPGRADE_VERSION=2017.3.0-rc11-37-g5d8c45d

PE_VERSION=2016.4.8
PE_UPGRADE_VERSION=2016.4.9-rc0-7-g78518c6

host_layout="$1"
n="$2"
results_dir="$3"

[[ -z "$host_layout" ]] && echo "$USAGE" && exit 1
[[ -z "$n" ]] && echo "$USAGE" && exit 1

run_id=${host_layout}_${PE_VERSION}_${PE_UPGRADE_VERSION}

[[ -z "$results_dir" ]] && results_dir="runs/${run_id}"

trap cleanup SIGINT SIGTERM

echo "Exporting the relevant environment variables ..."
export BEAKER_KEYFILE=~/.ssh/id_rsa-acceptance
export BEAKER_HELPER=lib/beaker_helper.rb
export BEAKER_PRESUITE=setup/install.rb,setup/agent_upgrade.rb
export BEAKER_TESTSUITE=acceptance/tests
export BEAKER_PRECLEANUP=acceptance/post
export pe_version="$PE_VERSION"
export pe_upgrade_version="$PE_UPGRADE_VERSION"

echoln "Generating the results directory and the hosts.cfg file ..."
mkdir -p $results_dir
hosts_cfg_content=`bundle exec beaker-hostgenerator "$host_layout" --global-config forge_host=forge-aio01-petest.puppetlabs.com`

if [[ $? -ne 0 ]]; then
  echoln "Failed to generate the hosts.cfg file. Clearing the results directory and exiting the script ..."
  rm -rf "$results_dir"
  exit 1
fi

hosts_cfg="${results_dir}/hosts.cfg"
echo "$hosts_cfg_content" > "$hosts_cfg"

for i in `seq $n`; do
  echoln "Creating temporary directory to store the log files..."

  log_prefix="${results_dir}/run${i}"

  echoln "Executing the agent upgrade ..."
  
  # Run the test command in the background. In the foreground, we poll for the
  # existence of the pre_suite-summary.txt file. When that file exists, then
  # our pre-suite/agent-upgrade has finished running. Thus, there is no need to
  # proceed further with the rest of the acceptance tests so we kill the background
  # process. 
  bundle exec beaker --hosts $hosts_cfg --type pe --keyfile $BEAKER_KEYFILE --tests $BEAKER_TESTSUITE --preserve-hosts never --helper $BEAKER_HELPER --pre-cleanup $BEAKER_PRECLEANUP --pre-suite $BEAKER_PRESUITE --log-prefix $log_prefix > /dev/null 2>&1 &

  # Get the directory containing all the log files (since logs are dated, we have to poll for
  # the creation of the log directory)
  log_dir="log/${log_prefix}"
  while [[ ! -d $log_dir ||  -z `ls $log_dir` ]]; do
    :
  done
  log_dir="${log_dir}/`ls $log_dir`"

  echo "Waiting for the creation of the pre_suite-summary.txt file ..."
  summary="${log_dir}/pre_suite-summary.txt"
  while [[ ! -a "$summary" ]]; do
    sleep 1
  done
  
  # Sleep a brief second so that beaker has time to finish writing
  # to this file, and then kill the background process
  echo "Killing the background agent upgrade process ..."
  sleep 1
  kill $(jobs -p)
  
  has_tests_that() {
    local category="$1"
    local occurrences=`sed -E -n "s/$category: ([0-9]|[1-9][0-9]+)/\1/p" "$summary"  | sed 's/[[:blank:]]//g'`
    [[ "$occurrences" -ne 0 ]]
  }
  
  echo "Checking if the agent upgrade resulted in any failures ..."
  
  if has_tests_that "Failed" || has_tests_that "Errored"; then
    echo "Agent upgrade run for $run_id resulted in a failure."
    echo "Copying this run's log and summary files to the results directory ..."
    for file in `find "$log_dir/" -name '*.log' -o -name '*.txt'`; do
      cp "$file" "$results_dir"
    done
    exit 0
  fi
  
  echo "This agent upgrade run resulted in a success!"
  echo "Doing the run again..."
done

echoln "None of the agent upgrade runs failed ..."
