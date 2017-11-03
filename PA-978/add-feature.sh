#!/usr/bin/env bash

num="$1"
feature="feature${num}"

echo "978.${num}" > "${feature}"
git add "${feature}"
git commit -m "Added feature ${num}"
git push
git rev-parse HEAD
