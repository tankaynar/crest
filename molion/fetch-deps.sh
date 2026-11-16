#!/usr/bin/env bash
# Clones the libraries molion/deps.txt pins into deps/<name>.
#
#     molion/fetch-deps.sh
set -euo pipefail
mkdir -p deps
grep -v '^#' molion/deps.txt | while read -r name url tag; do
  [ -n "$name" ] || continue
  rm -rf "deps/$name"
  git -c advice.detachedHead=false clone -q --depth 1 --branch "$tag" "$url" "deps/$name"
  echo "$name $tag $(git -C "deps/$name" rev-parse HEAD)"
done
