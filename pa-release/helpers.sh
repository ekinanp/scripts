#!/usr/bin/env bash

# utility routines
fsed() {
  local action="$1"
  local file="$2"

  sed -E "s/${action}/" "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
}

fawk() {
  local code="$1"
  local file="$2"
  
  awk "${code}" "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
}

# read as "fawk" after first match
fawk_afm() {
  local regex="$1"
  local code="$2"
  local file="$3"

  # Code skeleton obtained from:
  #   https://stackoverflow.com/questions/32007152/insert-multiple-lines-of-text-before-specific-line-using-sed
  #
  # TODO: Refactor this to be more "awky"
  fawk "
    BEGIN {
      matched=0
    }
    { print }
    /${regex}/ {
      if ( matched == 0 ) {
        ${code}
        matched=1
      }
    }
  " "${file}"
}

repo_url() {
  local github_user="$1"
  local repo="$2"

  echo "git@github.com:${github_user}/${repo}.git"
}

validate_arg() {
  local arg="$1"

  if [[ -z "${arg}" ]]; then
    echo "USAGE: ./bump-component.sh <component> <branch> <version> <jira-ticket>"
    exit 1
  fi
}

clone_clean_repo() {
  local workspace="$1"
  local fork_user="$2"
  local repo="$3"
  local branch="$4"

  pushd "${workspace}"
    rm -rf "${repo}"
    git clone `repo_url ${fork_user} ${repo}` "${repo}"
    pushd "${repo}"
      git remote add upstream `repo_url puppetlabs ${repo}`
      git fetch upstream
      git checkout -b "${branch}" "upstream/${branch}" 
      git push --set-upstream origin "${branch}" --force 
    popd
  popd
}
