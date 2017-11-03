#!/usr/bin/env bash

HELPERS=/Users/enis.inan/GitHub/scripts/pa-release/helpers.sh
source "${HELPERS}"

RUN_TICKETMATCH=/Users/enis.inan/GitHub/scripts/pa-release/run-ticketmatch.sh
WORKSPACE=/Users/enis.inan/GitHub/scripts/pa-release/ticketmatch-ws
RESULTS_DIR=/Users/enis.inan/GitHub/scripts/pa-release/ticketmatch-results

# each element is interpreted as:
#   <repo>:<git-from-rev>:<git-to-rev>:<jira-project>:'<jira-fix-version>'
TICKET_MATCH_INPUT_RE="([^:#]+):([^:#]+):([^:#]+):([^:#]+):'([^:'#]+)'"
TICKETMATCH_INPUTS=(
  "puppet-agent:5.3.2:5.3.x:PA:'puppet-agent 5.3.3'"
  "facter:3.9.2:3.9.x:FACT:'FACT 3.9.3'"
  "puppet:5.3.2:5.3.x:PUP:'PUP 5.3.3'"
  "marionette-collective:2.11.3:2.11.x:MCO:'MCO 2.11.4'"
  "cpp-pcp-client:1.5.4:1.5.x:PCP:'cpp-pcp-client 1.5.5'"
  "pxp-agent:1.8.0:1.8.x:PCP:'pxp-agent 1.8.1'"
)

for input in "${TICKETMATCH_INPUTS[@]}"; do
  old_ifs=IFS
  IFS=#
  # parse out the individual parts of the input. for some reason, read does not work properly
  # with this, so need to store the result in an array first and then individually assign the
  # pieces
  parsed_input=(`echo "${input}" | sed -n -E "s/${TICKET_MATCH_INPUT_RE}/\\1#\\2#\\3#\\4#\\5/p"`)
  repo=${parsed_input[0]}
  git_from_rev=${parsed_input[1]}
  git_to_rev=${parsed_input[2]}
  jira_project=${parsed_input[3]}
  jira_fix_version=${parsed_input[4]}
  IFS="${old_ifs}"

  lazy_clone_clean_repo "${WORKSPACE}" "${GITHUB_USER}" "${repo}" "${git_to_rev}"

  pushd "${WORKSPACE}"
    pushd "${repo}"
      echo "Running ticketmatch on ${repo} ..."
      outfile="${RESULTS_DIR}/${repo}.txt"
      ${RUN_TICKETMATCH} "${git_from_rev}" "${git_to_rev}" "${jira_project}" "${jira_fix_version}" | tee "${outfile}"

      echo ""
      echo ""
    popd
  popd
done
