#!/usr/bin/env bash

HELPERS=/Users/enis.inan/GitHub/scripts/pa-release/helpers.sh
source "${HELPERS}"

WORKSPACE=/Users/enis.inan/GitHub/scripts/pa-release/releasebranch-ws
USAGE="./cut-release-branch.sh <sha> <release-branch>"
# TODO: This should be updated each time a new release is about to happen.
PREVIOUS_RELEASE="5.3.2"

sha="$1"
release_branch="$2"

validate_arg "${USAGE}" "${sha}"
validate_arg "${USAGE}" "${release_branch}"

release_branch="${release_branch}_release"

# parse out the major and minor versions
parsed_branch=(`echo "${release_branch}" | sed -n -E "s/([0-9]+)\.([0-9]+)\..+/\\1 \\2/p"`)
major="${parsed_branch[0]}"
minor="${parsed_branch[1]}"

version_branch="${major}.${minor}.x"

# TODO: Change user to puppetlabs when cloning puppet-agent
clone_clean_repo "${WORKSPACE}" "${GITHUB_USER}" "puppet-agent" "${version_branch}"
clone_clean_repo "${WORKSPACE}" "${GITHUB_USER}" "ci-job-configs" master
pushd "${WORKSPACE}"
  pushd "puppet-agent"
    git checkout -b "${release_branch}" "${sha}"
    git push --set-upstream origin "${release_branch}" --force
  popd
  pushd "ci-job-configs"
    jenkins_branch="create_${release_branch}_pipelines"
    git checkout -b "${jenkins_branch}"
    git push --set-upstream origin "${jenkins_branch}" --force
    puppet_agent_yaml="jenkii/jenkins-master-prod-1/projects/puppet-agent.yaml"
    fsed "([ ]+scm_branch:[ ]+)'${PREVIOUS_RELEASE}_release'/\\1'${release_branch}'" "${puppet_agent_yaml}"
  popd
popd
