#!/usr/bin/env bash

SCRIPTS_ROOT=/Users/enisinan/GitHub/scripts
TICKET_NUMBER="PA-1697"
source "${SCRIPTS_ROOT}/${TICKET_NUMBER}/helpers.sh"

USAGE="./init-component.sh <component>"
component="$1"

validate_arg "${USAGE}" "${component}"

json_path="configs/components/${component}.json"
pushd "${PUPPET_AGENT_DIR}"
  ref=`jq -r ".ref" ${json_path}`
popd

reset_repo "${component}" "${ref}"
update_component_ref "${component}" "${TICKET_BRANCH}"
