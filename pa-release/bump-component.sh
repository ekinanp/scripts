#!/usr/bin/env bash

HELPERS=/Users/enis.inan/GitHub/scripts/pa-release/helpers.sh
source "${HELPERS}"

VERSION_RE="[0-9]+\.[0-9]+\.[0-9]+"

bump_cpp_project() {
  local project="$1"
  local version="$2"
  local changes="$3"

  fsed "project\(${project} VERSION ${VERSION_RE}\)/project(${project} VERSION ${version})" CMakeLists.txt
  fsed "Project-Id-Version: ${project} ${VERSION_RE}/Project-Id-Version: ${project} ${version}" locales/${project}.pot

  if [[ -z "${changes}" ]]; then
    return 0
  fi

  # prepends relevant changelog entries
  (echo "## ${version}" && echo "" && echo "${changes}"  && echo "") | cat - CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
}

# these routines do the version bump for each component.
# before executing them, make sure that you are in that
# specific component's repo directory
leatherman() {
  local version="$1"
  local change_text=
  # Add any CHANGELOG updates here.
  read -r -d '' change_text <<'EOF'
This is a feature release.
EOF

  bump_cpp_project leatherman "${version}" "${change_text}"
}

bump_puppet() {
  local version="$1"

  fsed "([ ]+ PUPPETVERSION = )'${VERSION_RE}'/\\1'${version}'" lib/puppet/version.rb
  fsed "([ ]+ version = )\"${VERSION_RE}\"/\\1\"${version}\"" .gemspec
}

pxp_agent() {
  local version="$1"
  local change_text=
  # Add any CHANGELOG updates here.
  read -r -d '' change_text <<'EOF'
This is a feature release.
EOF

  bump_cpp_project pxp-agent "${version}" "${change_text}"
}

cpp_pcp_client() {
  local version="$1"
  local change_text=
  # Add any CHANGELOG updates here.
  read -r -d '' change_text <<'EOF'
This is a feature release.
EOF

  bump_cpp_project cpp-pcp-client "${version}" "${change_text}"
}

marionette_collective() {
  local version="$1"

  fsed "([ ]+ VERSION=)\"${VERSION_RE}\"/\\1\"${version}\"" lib/mcollective.rb 

  local date="2017/10/26"
  local add_changelog_updates=
  # Add the CHANGELOG updates here. Note that every line here should be of the form:
  #   print "<line>"
  # to make it easy to insert into awk below.
  read -r -d '' add_changelog_updates <<EOF
print "|${date}|Release *${version}*||"
print "|2017/09/25|Restarting the mcollective service no longer kills running agent subprocesses|MCO-816|"
EOF

  # Update the website/changelog.md
  fawk_afm "\|----\|-----------\|------\|" "${add_changelog_updates}" website/changelog.md

  # Now update the website/releasenotes.md file.
  #
  # TODO: Could calculate previous_version instead of
  # hardcode it. Maybe add this feature later.
  local previous_version="2.11.3"
  local add_release_notes_updates=
  read -r -d '' add_release_notes_updates <<EOF
  print ""
  print "<a name=\"${version/\./_}\">&nbsp;</a>"
  print ""
  print "## ${version} - ${date}"
  print ""
  print "### Changes since ${previous_version}" 
  print ""
  print "|Date|Description|Ticket|"
  print "|----|-----------|------|"
  ${add_changelog_updates}
EOF

  # Update the website/releasenotes.md file
  fawk_afm "will be highlighted here" "${add_release_notes_updates}" website/releasenotes.md
}

puppet() {
  local version="$1"

  bump_puppet "${version}"
}

puppet_cve_test() {
  local version="$1"

  bump_puppet "${version}"
}

facter() {
  local version="$1"

  bump_cpp_project FACTER "${version}"
  fsed "PROJECT_NUMBER([ ]+) = ${VERSION_RE}/PROJECT_NUMBER\\1 = ${version}" lib/Doxyfile
}

# TODO: Once the script is ready, and all version updates have been tested, uncomment
# the below parts, as this contains the core functionality
GITHUB_USER="ekinanp"
WORKSPACE=/Users/enis.inan/GitHub/scripts/pa-release/bumping-ws

component="$1"
branch="$2"
version="$3"
jira_ticket="$4"

validate_arg "${component}"
validate_arg "${branch}"
validate_arg "${version}"
validate_arg "${jira_ticket}"

clone_clean_repo "${WORKSPACE}" "${GITHUB_USER}" "${component}" "${branch}"

pushd "${WORKSPACE}"
  pushd "${component}"
    underscored_component=${component//-/_}
    ${underscored_component} ${version}
    git add -u
    msg="(${jira_ticket}) Prepare for ${version} release"
    git commit -m "${msg}"
    git push

    hub pull-request -b "puppetlabs:${branch}" -m "${msg}"
  popd
popd
