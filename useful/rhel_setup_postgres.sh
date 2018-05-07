#!/usr/bin/env bash

function create_self_signed_cert() {
  local pgdata="$1"

  pushd "${pgdata}"
    openssl req -new -text -out server.req
    openssl rsa -in privkey.pem -out server.key
    openssl req -x509 -in server.req -text -key server.key -out server.crt
    chmod og-rwx server.key
  popd
}

yum install -y postgresql postgresql-server postgresql-contrib vim
echo ":color desert" > ~/.vimrc
postgresql-setup initdb
systemctl start postgresql
systemctl enable postgresql
runuser -l postgres -c '(echo puppet && echo puppet) | createuser -DRSP razor'
runuser -l postgres -c 'createdb -E UTF8 -O razor razordb'

# Configure to listen on all addresses
echo "listen_addresses = '*'" >> /var/lib/pgsql/data/postgresql.conf

# Export PGDATA to use in scripts
echo "export PGDATA='/var/lib/pgsql/data'" >> ~/.bash_profile

systemctl restart postgresql
