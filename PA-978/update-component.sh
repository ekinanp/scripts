#!/usr/bin/env bash

set -e

GITHUB_DIR=/Users/enis.inan/GitHub
PA978_FILE=${GITHUB_DIR}/ci-job-configs/jenkii/jenkins-master-prod-1/projects/pa978.yaml

component="$1"
message="$2"

if [[ -z "${component}" ]]; then
  echo "USAGE: ./update-component.sh <component> [message]"
  exit 1
fi

underscored_component=${component/-/_}
num=`jq ."${underscored_component}" components.json`
pushd "${GITHUB_DIR}/${component}"
  sha=`${GITHUB_DIR}/scripts/PA-978/add-feature.sh "${num}" | tail -1`
popd
tag="${num}"

jq -r ".${underscored_component} |= $((num+1))" components.json > components.json.tmp && mv components.json.tmp components.json

component_re="${component}:([^:#]+):([[:xdigit:]]+)(:'([^'#]*)')?"
substitution="${component}:${tag}:${sha}"
if [[ -n "${message}" ]]; then
  substitution="${substitution}:'${message}'"
fi

sed -E "s/${component_re}/${substitution}/" ${PA978_FILE} > ${PA978_FILE}.tmp && mv ${PA978_FILE}.tmp ${PA978_FILE}
