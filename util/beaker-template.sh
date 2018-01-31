# Get the arguments
USAGE="${SCRIPT_NAME} <host-layout> [results-dir]"

host_layout="$1"
results_dir="$2"

[[ -z "${host_layout}" ]] && echo "${USAGE}" && exit 1
[[ -z "${results_dir}" ]] && results_dir=`generate_default_results_dir "${host_layout}"`

echo "Installing the relevant gems ..."
BUNDLE_PATH=.bundle/gems
BUNDLE_BIN=.bundle/bin
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
