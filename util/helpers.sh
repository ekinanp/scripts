#!/usr/bin/env bash

# utility routines
fjq() {
  local action="$1"
  local file="$2"

  jq -r --compact-output "${action}" "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
}

fsed() {
  local action="$1"
  local file="$2"

  sed -E "${action}" "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
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
  local usage="$1"
  local arg="$2"

  if [[ -z "${arg}" ]]; then
    echo "USAGE: ${usage}"
    exit 1
  fi
}

clone_repo() {
  local workspace="$1"
  local fork_user="$2"
  local repo="$3"
  local checkout="$4"

  pushd "${workspace}"
    rm -rf "${repo}"
    git clone `repo_url ${fork_user} ${repo}` "${repo}"
    pushd "${repo}"
      ${checkout}
    popd
  popd
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

lazy_clone_clean_repo() {
  local workspace="$1"
  local fork_user="$2"
  local repo="$3"
  local branch="$4"

  if [[ ! -d "${WORKSPACE}/${repo}" ]]; then
    clone_clean_repo "${WORKSPACE}" "${fork_user}" "${repo}" "${branch}"
  fi
}

checkout_repo() {
  local workspace="$1"
  local fork_user="$2"
  local repo="$3"
  local ref="$4"

  pushd "${workspace}"
    if [[ ! -d "${repo}" ]]; then
       git clone `repo_url ${fork_user} ${repo}` "${repo}"
    fi
    pushd "${repo}"
      git fetch
      git checkout "${ref}"
    popd
  popd
}

make_host_json() {
  local host_type="$1"

  for host_engine in "vmpooler" "nspooler"; do
    if [[ "${host_engine}" == "vmpooler" ]]; then
      jq_cmd=".\"${host_type}\""
      vm=`${VMFLOATY} get "${host_type}" 2>&1`
    else
      jq_cmd=".\"${host_type}\".hostname"
      vm=`${VMFLOATY} get "${host_type}" --service ns 2>&1`
    fi

    if [[ "$?" -ne 0 ]]; then
      continue
    fi

    host_name=`echo "${vm}" | jq -r "${jq_cmd}"`
    echo "{\"hostname\":\"${host_name}\",\"type\":\"${host_type}\",\"engine\":\"${host_engine}\"}"
    return 0
  done

  return 1
}

query_vmfloaty() {
  local query="$1"
  local cmd="${VMFLOATY} ${query}"

  ${cmd} && ${cmd} --service ns
}


# Common constants that may be shared throughout scripts
VMFLOATY="floaty"
