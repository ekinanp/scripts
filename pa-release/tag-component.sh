#!/usr/bin/env bash

HELPERS=/Users/enis.inan/GitHub/scripts/pa-release/helpers.sh
source "${HELPERS}"

GITHUB_USER="ekinanp"
WORKSPACE=/Users/enis.inan/GitHub/scripts/pa-release/tagging-ws
HIPCHAT_ROOM_MESSAGE=/Users/enis.inan/GitHub/hipchat-cli/hipchat_room_message
RELEASE_BRANCH="5.3.2"
HIPCHAT_ROOM_ID="4258397"


#component="$1"
#new_tag="$2"
#
#validate_arg "${component}"
#validate_arg "${new_tag}"
#
#lazy_clone_clean_repo "${WORKSPACE}" "${GITHUB_USER}" "puppet-agent" "${RELEASE_BRANCH}"
#
#pushd "${WORKSPACE}"
#  pushd "puppet-agent"
#    json_path="configs/components/${component}.json"
#    sha="jq -r '.ref' ${json_path}"
#    ${HIPCHAT_ROOM_MESSAGE} -r "${HIPCHAT_ROOM_ID}" -i "! tag ${component} ${new_tag} at ${sha} with \"${new_tag}\""
#
#    # wait for the tag to complete
#    sleep 1
#
#    # update the component/json file
#    fjq ".ref |= refs/tags/${new_tag}" "${json_path}"
#  popd
#popd
