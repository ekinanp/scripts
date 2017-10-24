#!/usr/bin/env bash

PUPPET_AGENT_DIR=/Users/enis.inan/GitHub/puppet-agent
INIT_PA_COMPONENTS=/Users/enis.inan/GitHub/scripts/PA-978/init-pa-components.sh

pushd ${PUPPET_AGENT_DIR}
  git checkout master
  git branch -D PA-978
  git checkout -b PA-978
  git push --set-upstream origin PA-978 --force
popd

${INIT_PA_COMPONENTS}
