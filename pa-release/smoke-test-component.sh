#!/usr/bin/env bash

HELPERS=/Users/enis.inan/GitHub/scripts/pa-release/helpers.sh
source "${HELPERS}"

set -e

USAGE="./smoke-test-component.sh <component> <version>"
TEST_PLATFORM="redhat-7-x86_64"

component="$1"
version="$2"

validate_arg "${USAGE}" "${component}"
validate_arg "${USAGE}" "${version}"

host=`floaty get "${TEST_PLATFORM}" | jq -r ".\"${TEST_PLATFORM}\""`

if [[ "${component}" == "mcollective" ]]; then
  gem_file="mcollective-client-${version}.gem"
  cmd="/usr/local/share/gems/gems/mcollective-client-2.11.3/bin/mco"
else
  gem_file="${component}-${version}.gem"
  cmd="${component}"
fi

ssh -t -oStrictHostKeyChecking=no root@${host} "curl -O http://builds.delivery.puppetlabs.net/${component}/${version}/shipped/${gem_file}"
ssh -t -oStrictHostKeyChecking=no root@${host} "gem install ${gem_file}"
displayed_version=`ssh -t -oStrictHostKeyChecking=no root@${host} "${cmd} --version" | tail -1`

floaty delete "${host}"

echo ""
echo "OUTPUT: ${displayed_version}"
