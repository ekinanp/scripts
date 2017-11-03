#!/usr/bin/env bash

set -e

GITHUB_DIR=/Users/enis.inan/GitHub/scripts/PA-978/workspace
PA978_FILE=/Users/enis.inan/GitHub/ci-job-configs/jenkii/jenkins-master-prod-1/projects/puppet-agent.yaml
PA_BRANCH="PA-978"

component="$1"

if [[ -z "${component}" ]]; then
  echo "USAGE: ./update-component.sh <component>"
  exit 1
fi

underscored_component=${component/-/_}
num=`jq ."${underscored_component}" components.json`
pushd "${GITHUB_DIR}"
  pushd "${component}"
    sha=`/Users/enis.inan/GitHub/scripts/PA-978/add-feature.sh "${num}" | tail -1`
  popd
  pushd "puppet-agent"
    git pull
    component_json="configs/components/${component}.json"
    jq --compact-output ".ref |= \"${sha}\"" "${component_json}" > "${component_json}.tmp" && mv "${component_json}.tmp" "${component_json}"
    git add -u
    git commit -m "Updating ${component}'s sha with the sha to tag with!"
    git push
  popd
popd
tag=978."${num}"

jq -r ".${underscored_component} |= $((num+1))" components.json > components.json.tmp && mv components.json.tmp components.json

component_re="${component}:([^ ]+)"
substitution="${component}:${tag}"

sed -E "s/${component_re}/${substitution}/" ${PA978_FILE} > ${PA978_FILE}.tmp && mv ${PA978_FILE}.tmp ${PA978_FILE}
