#!/usr/bin/env bash

merge_sha="$1"
passing_sha="$2"

git merge-base --is-ancestor "${merge_sha}" "${passing_sha}"

if [[ "$?" -eq 0 ]]; then
  echo "True"
else
  echo "False"
fi
