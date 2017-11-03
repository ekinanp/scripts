#!/usr/bin/env bash

HELPERS=/Users/enis.inan/GitHub/scripts/pa-release/helpers.sh
source "${HELPERS}"

WORKSPACE="${TAGGING_WORKSPACE}"
USAGE="./pin-back-component.sh <component> <branch>"

component="$1"
branch="$2"

validate_arg "${USAGE}" "${component}"
validate_arg "${USAGE}" "${branch}"

checkout_repo "${WORKSPACE}" "${GITHUB_USER}" "${component}" "${branch}"

# parse out the major and minor versions
parsed_branch=(`echo "${branch}" | sed -n -E "s/([0-9]+)\.([0-9]+)\..+/\\1 \\2/p"`)
major="${parsed_branch[0]}"
minor="${parsed_branch[1]}"

pushd "${WORKSPACE}"
  # find the most previous tag
  pushd "${component}"
    prev_tag=`git tag | grep "${major}\.${minor}" | tail -1`
  popd
  checkout_repo "${WORKSPACE}" "${GITHUB_USER}" "puppet-agent" "${RELEASE_BRANCH}"
  pushd "puppet-agent"
    # update the component/json file
    fjq ".ref |= \"refs/tags/${new_tag}\"" "configs/components/${component}.json"
  popd
popd
