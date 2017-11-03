#!/usr/bin/env bash

INIT_COMPONENT=/Users/enis.inan/GitHub/scripts/PA-978/init-component.sh
UPDATE_COMPONENT=/Users/enis.inan/GitHub/scripts/PA-978/update-component.sh
COMPONENTS=("leatherman" "facter" "pxp-agent" "puppet" "hiera" "marionette-collective")

for component in "${COMPONENTS[@]}"; do
  ${INIT_COMPONENT} ${component}
  ${UPDATE_COMPONENT} ${component}
done
