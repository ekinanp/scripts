#!/usr/bin/env bash

SCRIPTS_ROOT=/Users/enisinan/GitHub/scripts
TICKET_NUMBER="PA-1697"
source "${SCRIPTS_ROOT}/${TICKET_NUMBER}/helpers.sh"

INIT_COMPONENT=${SCRIPTS_ROOT}/${TICKET_NUMBER}/init-component.sh
UPDATE_COMPONENT=${SCRIPTS_ROOT}/${TICKET_NUMBER}/update-component.sh
COMPONENTS=("leatherman" "facter" "pxp-agent" "puppet" "hiera" "marionette-collective")

for component in "${COMPONENTS[@]}"; do
  ${INIT_COMPONENT} ${component}
  ${UPDATE_COMPONENT} ${component}
done
