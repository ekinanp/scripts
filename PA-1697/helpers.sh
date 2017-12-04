#!/usr/bin/env bash

source "${SCRIPTS_ROOT}/util/helpers.sh"

TICKET_NUMBER="PA-1697"
WORKSPACE="${SCRIPTS_ROOT}/${TICKET_NUMBER}/workspace"
PUPPET_AGENT_DIR="${WORKSPACE}/puppet-agent"
PUPPET_AGENT_YAML="/Users/enis.inan/GitHub/ci-job-configs/jenkii/jenkins-master-prod-1/projects/puppet-agent.yaml"
TICKET_BRANCH="${TICKET_NUMBER}"
REPOS_JSON="${SCRIPTS_ROOT}/${TICKET_NUMBER}/repos.json"
TAG_PREFIX="${TICKET_NUMBER//PA-/}"

reset_repo() {
  local repo="$1"
  local ref="$2"

  clone_clean_repo "${WORKSPACE}" "ekinanp" "${repo}" "${ref}"
  pushd "${WORKSPACE}/${repo}"
    git branch -D "${TICKET_BRANCH}"
    git checkout -b "${TICKET_BRANCH}"
    git push --set-upstream origin "${TICKET_BRANCH}" --force
  popd

  underscored_repo="${repo//-/_}"
  fjq ".${underscored_repo} = 1" "${REPOS_JSON}"
}

next_update_json() {
  local repo="$1"
  local underscored_repo="${repo//-/_}"
  local num=`jq ."${underscored_repo}" "${REPOS_JSON}"`

  echo "{\"num\": ${num}, \"tag\": \"${TAG_PREFIX}.${num}\"}"
}

update_repo() {
  local repo="$1"
  local num="$2"
  local new_tag="$3"
  local feature_file="feature_${num}"

  pushd "${WORKSPACE}/${repo}"
    git pull
    echo "${new_tag}" > "${feature_file}"
#    echo "foo" > "${feature_file}"

    git add "${feature_file}"
    git commit -m "Added Feature ${num}"
    git push
    local sha=`git rev-parse HEAD`
  popd

  local underscored_repo="${repo//-/_}"
  fjq ".${underscored_repo} |= $((num+1))" ${REPOS_JSON}

  echo "${sha}"
}

update_component_ref() {
  local component="$1"
  local new_ref="$2"

  pushd "${PUPPET_AGENT_DIR}"
    component_json="configs/components/${component}.json"
    fjq ".ref |= \"${new_ref}\"" "${component_json}"
    # update the url just to be safe
    fjq ".url |= \"git@github.com:ekinanp/${component}.git\"" "${component_json}"
    git add "${component_json}"
    git commit -m "bumping ${component} to ${new_ref}"
    git push --set-upstream origin "${TICKET_BRANCH}" --force
  popd
}
