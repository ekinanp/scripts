#!/usr/bin/env bash

TILDE=/Users/enisinan
TICKET="PE-22821"
REPO_ROOT="${TILDE}/GitHub/pe_acceptance_tests"
SCRIPTS_ROOT="${REPO_ROOT}/scripts"
RUN_BEAKER_PATH="${TILDE}/GitHub/scripts/agent-upgrade/run-beaker.sh"
PREFIX="branches"

# Get the arguments

branch="$1"

if [[ -z "$branch" ]]; then
  echo "./prepare_branch <branch>"
  exit 1
fi

# Copy run-beaker.sh and commit it.

pushd "$REPO_ROOT"
git checkout "$branch"
if [[ "$?" -ne 0 ]]; then
  echo "ERROR: $PREFIX does not have a branch called $branch to check-out from!"
  exit 1
fi

ticket_branch="${TICKET}_${branch}"
git checkout -b "${ticket_branch}" || git checkout "${ticket_branch}"
mkdir "$SCRIPTS_ROOT"
cp "$RUN_BEAKER_PATH" "${SCRIPTS_ROOT}/"
git add "${SCRIPTS_ROOT}/run-beaker.sh" 
git commit -m "Added the run-beaker.sh script to use for running acceptance tests!"

# TAR it up and extract it in the ${PREFIX}/${branch} directory
branch_tar="${branch}.tar"
branch_dir="${PREFIX}/${branch}"
git archive HEAD --format=tar -o "$branch_tar"
mkdir -p "$branch_dir"
cp "$branch_tar" "$branch_dir"
pushd "$branch_dir"
tar -xvf "$branch_tar" 

# clean-up
popd
popd
rm "$branch_tar"
git checkout "${branch}"
git branch -D "${ticket_branch}"
