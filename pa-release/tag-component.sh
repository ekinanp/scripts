#!/usr/bin/env bash

HELPERS=/Users/enis.inan/GitHub/scripts/pa-release/helpers.sh
source "${HELPERS}"

WORKSPACE="${TAGGING_WORKSPACE}"
HIPCHAT_ROOM_MESSAGE=/Users/enis.inan/GitHub/hipchat-cli/hipchat_room_message
HIPCHAT_ROOM_ID="322589"
USAGE="./tag-component.sh <component> <new_tag>"

component="$1"
new_tag="$2"

validate_arg "${USAGE}" "${component}"
validate_arg "${USAGE}" "${new_tag}"

checkout_repo "${WORKSPACE}" "${GITHUB_USER}" "puppet-agent" "${RELEASE_BRANCH}"

pushd "${WORKSPACE}"
  pushd "puppet-agent"
    json_path="configs/components/${component}.json"
    sha=`jq -r '.ref' ${json_path}`
    ${HIPCHAT_ROOM_MESSAGE} -r "${HIPCHAT_ROOM_ID}" -i "! tag ${component} ${new_tag} at ${sha} with \"${new_tag}\""
    new_ref="refs/tags/${new_tag}"
    # update the component/json file
    fjq ".ref |= \"${new_ref}\"" "${json_path}"
  popd
  checkout_repo "${WORKSPACE}" "${GITHUB_USER}" "${component}" "${new_ref}"
  pushd "${component}"
    echo "Running git describe to make sure the tag makes sense/is correct"
    git describe
  popd
popd
