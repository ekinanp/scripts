#!/bin/bash

set -e

function identify_master() {
  local master_vm="$1"

  if [[ "${master_vm}" == "${master_vm1}" ]]; then
    echo "master1"
  else
    echo "master2"
  fi
}

function on_host() {
  local host="$1"
  local cmd="$2"
  local suppress="$3"

  if [[ -z "${suppress}" || "${suppress}" == "false" ]]; then
    ssh -oStrictHostKeyChecking=no root@${host} "${cmd} 2>&1" 2>/dev/null
  else
    ssh -oStrictHostKeyChecking=no root@${host} "${cmd} 2>&1" 2>/dev/null 1>/dev/null
  fi
}

function on_master() {
  local master_vm="$1"
  local cmd="$2"
  local suppress="$3"

  echo ""
  echo "### DEBUG: Running the following command on `identify_master ${master_vm}`"
  echo "  ${cmd}"
  echo "###"
  on_host ${master_vm} "${cmd}" "${suppress}"
}

function start_puppetdb() {
  local master_vm="$1"
  local which_master=`identify_master ${master_vm}`

  echo "STEP: Start PuppetDB and point it to puppetserver"
  on_master ${master_vm} "puppet resource service puppetdb ensure=running enable=true"
  local puppetdb_conf="/etc/puppetlabs/puppet/puppetdb.conf"
  on_master ${master_vm} "echo [main] > ${puppetdb_conf}"
  on_master ${master_vm} "echo server_urls = https://\`facter fqdn\`:8081 >> ${puppetdb_conf}"
  echo ""
  echo ""
  
  echo "STEP: Adding PuppetDB to storeconfigs and reports settings in puppet.conf"
  local puppet_conf="/etc/puppetlabs/puppet/puppet.conf"
  on_master ${master_vm} "echo storeconfigs = true >> ${puppet_conf}"
  on_master ${master_vm} "echo storeconfigs_backend = puppetdb >> ${puppet_conf}"
  on_master ${master_vm} "echo reports = store,puppetdb >> ${puppet_conf}"
  echo ""
  echo ""
  
  echo "STEP: Creating route_file with puppetdb terminus for facts"
  local route_file
  route_file=`on_master ${master_vm} "puppet master --configprint route_file" | tail -n 1`
  on_master ${master_vm} "echo --- > ${route_file}"
  on_master ${master_vm} "echo master: >> ${route_file}"
  on_master ${master_vm} "echo \"  facts:\" >> ${route_file}"
  on_master ${master_vm} "echo \"    terminus: puppetdb\" >> ${route_file}"
  on_master ${master_vm} "echo \"    cache: yaml\" >> ${route_file}"
  echo ""
  echo ""
  
  echo "STEP: Setting ownership on everything"
  on_master ${master_vm} 'chown -R puppet:puppet `puppet config print confdir`'
  echo ""
  echo ""
  
  echo "STEP: Restart puppetserver and perform a puppet run to ensure that facts and reports are sent to PuppetDB"
  on_master ${master_vm} "puppet resource service puppetserver ensure=stopped"
  on_master ${master_vm} "puppet resource service puppetserver ensure=running"
  set +e
  on_master ${master_vm} "puppet agent -t"
  local exit_code="$?"
  set -e
  if [[ ! "${exit_code}" -eq 2 && ! "${exit_code}" -eq 0 ]]; then
    echo "Failed to start-up PuppetDB on ${which_master}!"
    echo "Exiting the script with a failure ..."
    exit 1
  fi
  on_master ${master_vm} "grep 'replace facts' /var/log/puppetlabs/puppetdb/puppetdb.log && echo '### Facts successfully sent to PuppetDB ###'"
  on_master ${master_vm} "grep 'replace catalog' /var/log/puppetlabs/puppetdb/puppetdb.log && echo '### Reports successfully sent to PuppetDB ###'"
  echo ""
  echo ""
}

function install_puppetdb_from_module() {
  local master_vm="$1"
  local which_master=`identify_master ${master_vm}`

  echo "STEP: Install PuppetDB from the module on ${which_master}!"
  on_master ${master_vm} "puppet module install puppetlabs-puppetdb"
  local site_pp="/etc/puppetlabs/code/environments/production/manifests/site.pp"
  on_master ${master_vm} "echo node \'\`facter fqdn\`\' { > ${site_pp}"
  on_master ${master_vm} "echo \"  include puppetdb\" >> ${site_pp}"
  on_master ${master_vm} "echo \"  include puppetdb::master::config\" >> ${site_pp}"
  on_master ${master_vm} "echo } >> ${site_pp}"
  on_master ${master_vm} "echo node default { >> ${site_pp}"
  on_master ${master_vm} "echo \"  notify { 'hello': message => 'hello world' }\" >> ${site_pp}"
  on_master ${master_vm} "echo } >> ${site_pp}"
  # puppet agent -t returns an exit code of 2 if changes are successfully applied
  set +e
  on_master ${master_vm} "puppet agent -t"
  if [[ ! "$?" -eq 2 ]]; then
    echo "Failed to install PuppetDB from the module on ${which_master}!"
    echo "Exiting the script with a failure ..."
    exit 1
  fi
  set -e
  echo ""
  echo ""

  start_puppetdb ${master_vm}
  echo "Finished installing PuppetDB via. the module on ${which_master}!"
  echo ""
  echo ""
}

function install_puppetdb_from_package() {
  local master_vm="$1"
  local which_master=`identify_master ${master_vm}`

  echo "STEP: Install PuppetDB from package on ${which_master}!"

  # FIXME: Parametrize on postgres version?
  echo "STEP: Set-up postgresql 9.6 to use with PuppetDB"
  on_master ${master_vm} "yum install -y https://yum.postgresql.org/9.6/redhat/rhel-7-x86_64/pgdg-redhat96-9.6-3.noarch.rpm"
  on_master ${master_vm} "yum install -y postgresql96-server postgresql96-contrib"
  on_master ${master_vm} "/usr/pgsql-9.6/bin/postgresql96-setup initdb"
  on_master ${master_vm} "puppet resource service postgresql-9.6 ensure=running enable=true"
  
  # Enters 'puppet' as the password.
  on_master ${master_vm} "runuser -l postgres -c '(echo puppet && echo puppet) | createuser -DRSP puppetdb'"
  on_master ${master_vm} "runuser -l postgres -c 'createdb -E UTF8 -O puppetdb puppetdb'"
  on_master ${master_vm} "runuser -l postgres -c \"psql puppetdb -c 'create extension pg_trgm'\""
  
  # Edit pg_hba.conf to use md5 authentication for all DB connections
  local pg_hba_path
  pg_hba_path=`on_master ${master_vm} "find / -name *pg_hba.conf | head -n 1" | tail -n 1`
  on_master ${master_vm} "echo local all all md5 > ${pg_hba_path}"
  on_master ${master_vm} "echo host all all 127.0.0.1/32 md5 >> ${pg_hba_path}"
  on_master ${master_vm} "echo host all all ::1/128 md5 >> ${pg_hba_path}"
  
  # Restart postgresql and ensure that the puppetdb user can authenticate
  # (you will need to enter the password then hit exit)
  on_master ${master_vm} 'service postgresql-9.6 restart'
  # Should list puppetdb as one of the users
  on_master ${master_vm} "echo puppet | psql -h localhost puppetdb puppetdb -c '\\du' | grep puppetdb"
  echo ""
  echo ""
  
  # Install the PuppetDB package
  echo "STEP: Installing the PuppetDB package ..."
  on_master ${master_vm} "yum install -y puppetdb-${puppetdb_version} puppetdb-termini-${puppetdb_version}"
  echo ""
  echo ""
  
  # Configure PuppetDB
  echo "STEP: Configuring the PuppetDB package ..."
  local puppetdb_database_ini="/etc/puppetlabs/puppetdb/conf.d/database.ini"
  on_master ${master_vm} "echo subname = //localhost:5432/puppetdb >> ${puppetdb_database_ini}"
  on_master ${master_vm} "echo username = puppetdb >> ${puppetdb_database_ini}"
  on_master ${master_vm} "echo password = puppet >> ${puppetdb_database_ini}"
  echo ""
  echo ""
  
  start_puppetdb ${master_vm}
  echo "Finished installing PuppetDB via. the package on ${which_master}!"
  echo ""
  echo ""
}

USAGE="USAGE: $0 <master-vm1> <master-vm2> <agent-version> <server-version> <puppetdb-version>"

master_vm1="$1"
master_vm2="$2"
agent_version="$3"
server_version="$4"
puppetdb_version="$5"

if [[ -z "${master_vm1}" || -z "${master_vm2}" || -z "${agent_version}" || -z "${server_version}" || -z "${puppetdb_version}}" ]]; then
  echo "${USAGE}"
  exit 1
fi

echo "Running '$0' with the following master hosts ..."
echo "  Master with PuppetDB installed via. module (master1): ${master_vm1}"
echo "  Master with PuppetDB installed via. package (master2): ${master_vm2}"
echo ""

echo "STEP: Install puppetserver and puppet-agent on both masters"
for master_vm in ${master_vm1} ${master_vm2}; do
  which_master=`identify_master ${master_vm}`
  on_master ${master_vm} "rpm -Uvh http://yum.puppetlabs.com/puppet5/puppet5-release-el-7.noarch.rpm" 

  echo "STEP: Install puppet-agent on ${which_master}"
  on_master ${master_vm} "yum install -y puppet-agent-${agent_version}"
  on_master ${master_vm} "echo \`facter ipaddress\` puppet > /etc/hosts"
  echo ""
  echo ""

  echo "STEP: Install puppetserver on ${which_master}"
  on_master ${master_vm} "yum install -y puppetserver-${server_version}"
  on_master ${master_vm} "puppet resource service puppetserver ensure=running"
  on_master ${master_vm} "puppet agent -t"
  echo ""
  echo ""
done

install_puppetdb_from_module "${master_vm1}"
install_puppetdb_from_package "${master_vm2}"

for master_vm in ${master_vm1} ${master_vm2}; do
  which_master=`identify_master ${master_vm}`
  enable_firewall="puppet apply -e \"firewall { '100 allow http and https access': dport => [80, 443, 8140], proto => tcp, action => accept, }\""

  echo "STEP: Open firewall for puppetserver on ${which_master}"
  if [[ "${master_vm}" == "${master_vm1}" ]]; then
    on_master "${master_vm}" "${enable_firewall}"
  else
    # Per the docs, this is expected to fail on the master that has PuppetDB
    # installed from the package.
    set +e
    on_master "${master_vm}" "${enable_firewall}"
    set -e
  fi
  echo ""
  echo ""
done

for master_vm in ${master_vm1} ${master_vm2}; do
  which_master=`identify_master ${master_vm}`
  SEMANTIC_VERSION_RE="[0-9]+\.[0-9]+\.[0-9]+"
  REQUIRED_PACKAGES="puppet5-release-${SEMANTIC_VERSION_RE}-1.el7\.noarch puppet-agent-${SEMANTIC_VERSION_RE}-1\.el7\.x86_64 puppetserver-${SEMANTIC_VERSION_RE}-1\.el7\.noarch puppetdb-${SEMANTIC_VERSION_RE}-1\.el7\.noarch puppetdb-termini-${SEMANTIC_VERSION_RE}-1\.el7\.noarch"

  echo "STEP: Verify that the required puppet packages are installed on ${which_master}!"
  grep_results=`on_master "${master_vm}" "rpm -qa | grep puppet"`
  for required_package in  ${REQUIRED_PACKAGES}; do

    concrete_package=`echo "${grep_results}" | grep -E  "${required_package}"`
    if [[ -n "${concrete_package}" ]]; then
      echo "The required puppet package is present on ${which_master} as ${concrete_package}!"
    else
      echo "The required puppet package ${required_package} is not found on ${which_master}!"
      echo ""
      echo "### EXPECTED TO MATCH: ####"
      echo "${REQUIRED_PACKAGES}" | tr " " "\n"
      echo "###"
      echo ""
      echo "### ACTUAL: ###" 
      echo "${grep_results}"
      echo "###"
      echo ""
      echo "Failing the tests ..."
      exit 1
    fi
  done
  echo ""
  echo ""
done
