#!/usr/bin/env bash

DELETE_COMPONENT=/Users/enis.inan/GitHub/scripts/PA-978/delete.py
COMPONENTS=("leatherman" "facter" "pxp-agent" "puppet" "hiera" "marionette-collective")

for component in "${COMPONENTS[@]}"; do
  python ${DELETE_COMPONENT} ${component}
done
