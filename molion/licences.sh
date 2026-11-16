#!/usr/bin/env bash
# Copies the licence files of CREST, of every subproject linked into it (the git submodules in
# subprojects/) and of the libraries molion/deps.txt pins (deps/) to <dir>/<project>/.
#
#     molion/licences.sh <dir>
set -euo pipefail

out="$1"
mkdir -p "$out/crest"
cp COPYING COPYING.LESSER "$out/crest/"
for project in subprojects/*/ deps/*/; do
  name=$(basename "$project")
  files=$(find "$project" -maxdepth 1 -type f \( -iname 'COPYING*' -o -iname 'LICENSE*' -o -iname 'LICENCE*' \))
  if [ -z "$files" ]; then
    echo "warning: no licence files found for $name"
    continue
  fi
  mkdir -p "$out/$name"
  cp $files "$out/$name/"
done
ls "$out"
