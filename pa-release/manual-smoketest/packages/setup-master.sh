#!/bin/bash

set -e

function on_host() {
  host="$1"
  cmd="$2"
  suppress="$3"

  if [[ -z "${suppress}" || "${suppress}" == "false" ]]; then
    ssh -oStrictHostKeyChecking=no root@${host} "${cmd}" 2>/dev/null
  else
    ssh -oStrictHostKeyChecking=no root@${host} "${cmd}" 2>/dev/null 1>/dev/null
  fi
}

function on_master() {
  cmd="$1"
  suppress="$2"

  echo ""
  echo "### DEBUG: Running the following command on the master"
  echo "  ${cmd}"
  echo "###"
  on_host ${master_vm} "${cmd}" "${suppress}"
}

USAGE="USAGE: $0 <master-vm> <agent-version> <server-version> <puppetdb-version>"

master_vm="$1"
agent_version="$2"
server_version="$3"
puppetdb_version="$4"

if [[ -z "${master_vm}" || -z "${agent_version}" || -z "${server_version}" || -z "${puppetdb_version}}" ]]; then
  echo "${USAGE}"
  exit 1
fi

echo "Running the script with the following package versions ..."
echo "  puppet-agent version: ${agent_version}"
echo "  puppetserver version: ${server_version}"
echo "  puppetdb version: ${puppetdb_version}"
echo ""


## PUPPET AGENT

# Install puppet-agent package
echo "STEP (1): Install the puppet-agent package"
on_master "curl -O http://builds.puppetlabs.lan/puppet-agent/${agent_version}/artifacts/el/7/PC1/x86_64/puppet-agent-${agent_version}-1.el7.x86_64.rpm"
on_master "rpm -ivh puppet-agent-${agent_version}-1.el7.x86_64.rpm"
echo ""
echo ""

## PUPPETSERVER

# Install puppetserver
echo "STEP (2): Install puppetserver"
on_master "curl -O http://builds.puppetlabs.lan/puppetserver/${server_version}/artifacts/el/7/puppet5/x86_64/puppetserver-${server_version}-1.el7.noarch.rpm"
# FIXME: Might need to parametrize on Java?
on_master "yum install -y java-1.8.0-openjdk-headless"
on_master "rpm -ivh puppetserver-${server_version}-1.el7.noarch.rpm"
on_master "echo \`facter ipaddress\` puppet > /etc/hosts"
echo ""
echo ""

# Start-up puppetserver and perform a puppet run to ensure that it is running
echo "STEP (3): Start-up puppetserver and perform a puppet run to ensure that it is running."
on_master "puppet resource service puppetserver ensure=running"
on_master "puppet agent -t"
echo ""
echo ""

## PUPPETDB

# Here we install puppetdb. To do so, we first set-up postgresql 9.6
# and use that to set-up the puppetdb user and database

# FIXME: Parametrize on postgres version?
echo "STEP (4): Set-up postgresql 9.6 to use with PuppetDB"
on_master "yum install -y https://yum.postgresql.org/9.6/redhat/rhel-7-x86_64/pgdg-redhat96-9.6-3.noarch.rpm"
on_master "yum install -y postgresql96-server postgresql96-contrib"
on_master "/usr/pgsql-9.6/bin/postgresql96-setup initdb"
on_master "puppet resource service postgresql-9.6 ensure=running enable=true"

# Enters 'puppet' as the password.
on_master "runuser -l postgres -c '(echo puppet && echo puppet) | createuser -DRSP puppetdb'"
on_master "runuser -l postgres -c 'createdb -E UTF8 -O puppetdb puppetdb'"
on_master "runuser -l postgres -c \"psql puppetdb -c 'create extension pg_trgm'\""

# Edit pg_hba.conf to use md5 authentication for all DB connections
pg_hba_path=`on_master "find / -name *pg_hba.conf | head -n 1" | tail -n 1`
on_master "echo local all all md5 > ${pg_hba_path}"
on_master "echo host all all 127.0.0.1/32 md5 >> ${pg_hba_path}"
on_master "echo host all all ::1/128 md5 >> ${pg_hba_path}"

# Restart postgresql and ensure that the puppetdb user can authenticate
# (you will need to enter the password then hit exit)
on_master 'service postgresql-9.6 restart'
# Should list puppetdb as one of the users
on_master "echo puppet | psql -h localhost puppetdb puppetdb -c '\\du'"
echo "### INFO: ^ Pausing for 10 seconds so you can verify that 'puppetdb' appears as one of the listed users. If not, hit Ctrl-C to avoid running the rest of the script."
sleep 10
echo ""
echo ""

# Install the PuppetDB package
echo "STEP (5): Installing the PuppetDB package ..."
on_master "curl -O http://builds.puppetlabs.lan/puppetdb/${puppetdb_version}/artifacts/el/7/puppet5/x86_64/puppetdb-termini-${puppetdb_version}-1.el7.noarch.rpm"
on_master "curl -O http://builds.puppetlabs.lan/puppetdb/${puppetdb_version}/artifacts/el/7/puppet5/x86_64/puppetdb-${puppetdb_version}-1.el7.noarch.rpm"
on_master "rpm -ivh puppetdb-${puppetdb_version}-1.el7.noarch.rpm puppetdb-termini-${puppetdb_version}-1.el7.noarch.rpm"
echo ""
echo ""

# Configure PuppetDB
echo "STEP (6): Configuring the PuppetDB package ..."
puppetdb_database_ini="/etc/puppetlabs/puppetdb/conf.d/database.ini"
on_master "echo subname = //localhost:5432/puppetdb >> ${puppetdb_database_ini}"
on_master "echo username = puppetdb >> ${puppetdb_database_ini}"
on_master "echo password = puppet >> ${puppetdb_database_ini}"
echo ""
echo ""

# Start PuppetDB and configure puppetserver to use it by creating a puppetdb.conf
# file
echo "STEP (7): Starting PuppetDB and then configuring puppetserver to use it"
on_master "puppet resource service puppetdb ensure=running enable=true"
puppetdb_conf="/etc/puppetlabs/puppet/puppetdb.conf"
on_master "echo [main] > ${puppetdb_conf}"
on_master "echo server_urls = https://\`facter fqdn\`:8081 >> ${puppetdb_conf}"
echo ""
echo ""

# Add PuppetDB to storeconfigs and reports settings in puppet.conf file
echo "STEP (8): Adding PuppetDB to storeconfigs and reports settings in puppet.conf"
puppet_conf="/etc/puppetlabs/puppet/puppet.conf"
on_master "echo storeconfigs = true >> ${puppet_conf}"
on_master "echo storeconfigs_backend = puppetdb >> ${puppet_conf}"
on_master "echo reports = store,puppetdb >> ${puppet_conf}"
echo ""
echo ""

# Create route_file with puppetdb terminus for facts
echo "STEP (9): Creating route_file with puppetdb terminus for facts"
route_file=`on_master "puppet master --configprint route_file" | tail -n 1`
on_master "echo --- > ${route_file}"
on_master "echo master: >> ${route_file}"
on_master "echo \"  facts:\" >> ${route_file}"
on_master "echo \"    terminus: puppetdb\" >> ${route_file}"
on_master "echo \"    cache: yaml\" >> ${route_file}"
echo ""
echo ""

# Set ownership on everything
echo "STEP (10): Setting ownership on everything"
on_master 'chown -R puppet:puppet `puppet config print confdir`'
echo ""
echo ""

# Restart puppetserver and perform a puppet run to ensure that facts and
# reports are sent to PuppetDB
echo "STEP (11): Restart puppetserver and perform a puppet run to ensure that facts and reports are sent to PuppetDB"
on_master "puppet resource service puppetserver ensure=stopped"
on_master "puppet resource service puppetserver ensure=running"
on_master "puppet agent -t"
on_master "grep 'replace facts' /var/log/puppetlabs/puppetdb/puppetdb.log && echo '### Facts successfully sent to PuppetDB ###'"
on_master "grep 'replace catalog' /var/log/puppetlabs/puppetdb/puppetdb.log && echo '### Reports successfully sent to PuppetDB ###'"
echo ""
echo ""

echo "Successfully set-up the master VM!"
