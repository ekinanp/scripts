#!/usr/bin/env bash

SCRIPTS_ROOT=/Users/enisinan/GitHub/scripts
TICKET_NUMBER="PA-1697"
source "${SCRIPTS_ROOT}/${TICKET_NUMBER}/helpers.sh"

set -e

USAGE="./update-component.sh <component>"
component="$1"

validate_arg "${USAGE}" "${component}"

next_update_json=`next_update_json "${component}"`
num=`echo "${next_update_json}" | jq -r '.num'`
new_tag=`echo "${next_update_json}" | jq -r '.tag'`

sha=`update_repo "${component}" "${num}" "${new_tag}" | tail -1`
update_component_ref "${component}" "${sha}"

component_re="${component}:([^ ]+)"
substitution="${component}:${new_tag}"
fsed "${component_re}/${substitution}" "${PUPPET_AGENT_YAML}" 
