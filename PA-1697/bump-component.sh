#!/usr/bin/env bash

SCRIPTS_ROOT=/Users/enis.inan/GitHub/scripts
TICKET_NUMBER="PA-1697"
source "${SCRIPTS_ROOT}/${TICKET_NUMBER}/helpers.sh"

set -e

USAGE="./bump-component.sh <component> <new_ref>"
component="$1"
new_ref="$2"

validate_arg "${USAGE}" "${component}"
validate_arg "${USAGE}" "${new_ref}"

update_component_ref "${component}" "${new_ref}"
