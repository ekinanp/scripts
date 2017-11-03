#!/usr/bin/env bash

SCRIPTS_ROOT=/Users/enis.inan/GitHub/scripts
TICKET_NUMBER="PA-1697"
source "${SCRIPTS_ROOT}/${TICKET_NUMBER}/helpers.sh"

set -e

next_update_json=`next_update_json "puppet-agent"`
num=`echo "${next_update_json}" | jq -r '.num'`
new_tag=`echo "${next_update_json}" | jq -r '.tag'`

update_repo "puppet-agent" "${num}" "${new_tag}"

# TODO: Add puppet_agent.yaml substitution here!
#component_re="${component}:([^ ]+)"
#substitution="${component}:${new_tag}"
#fsed -E "${component_re}/${substitution}" "${PUPPET_AGENT_YAML}" 
