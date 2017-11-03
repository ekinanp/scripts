#!/usr/bin/env bash

GITHUB_DIR=/Users/enis.inan/GitHub/scripts/PA-978/workspace
PROJECT_DIR="${GITHUB_DIR}/puppet-agent"
PA978_DIR=/Users/enis.inan/GitHub/scripts/PA-978

component="$1"

if [[ -z "${component}" ]]; then
  echo "USAGE: ./init-component.sh <component>"
  exit 1
fi

json_path="configs/components/${component}.json"
pushd "${PROJECT_DIR}"
  ref=`jq -r ".ref" ${json_path}`
popd

pushd "${GITHUB_DIR}"
  sudo rm -rf "${component}"
  url="git@github.com:ekinanp/${component}.git"

  git clone "${url}"
  pushd "${component}"
    git branch -D PA-978
    git checkout "${ref}"
    git checkout -b PA-978
    git push --set-upstream origin PA-978 --force
  popd
popd

pushd "${PROJECT_DIR}"
  jq -r ".url |= \"${url}\" | .ref |= \"PA-978\"" ${json_path} > ${json_path}.tmp && mv ${json_path}.tmp ${json_path}
  git add "${json_path}"
  git commit -m "Initialized the ${component} component!"
  git push --set-upstream origin PA-978 --force
popd

underscored_component="${component/-/_}"
echo "underscored_component " "${underscored_component}"
jq -r ".${underscored_component} = 1" components.json > components.json.tmp && mv components.json.tmp components.json
