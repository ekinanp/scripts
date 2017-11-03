#!/usr/bin/env bash

# TODO: Remove this!
GITHUB_ROOT="/Users/enis.inan/GitHub"

repo="$1"
new_tag="$2"
sha="$3"
message="$4"

if [[ -z "${repo}" || -z "${new_tag}" || -z "${sha}" ]]; then
  echo "USAGE: ./tag.sh <repo> <new_tag> <sha> [message]" 
  exit 1
fi

if [[ -z "${message}" ]]; then
  message="\"${new_tag}\""
fi

# TODO: In final version of this script, get the repo URL from the component.json
# file so that this variable should not be used.
repo_url="git@github.com:ekinanp/${repo}.git"
repo_dir="${GITHUB_ROOT}/${repo}"

# TODO: Use the "clone" routine from the Vanagon helpers script, to increase code
# reusability
git clone "${repo_url}" "${repo_dir}"
pushd "${repo_dir}"
  git tag -a "${new_tag}" "${sha}" -m "${message}"
  # TODO: Push these changes
  git push --tags
popd
