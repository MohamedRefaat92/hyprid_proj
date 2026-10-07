#!/usr/bin/env bash
# Make an input file or folder available to the project as a symlink in data/.
# Each pipeline run records the inputs (resolved path, format, owner, size, time) in its reports.
#
#   scripts/sh/link-input.sh <path> [name]     name defaults to the file's own name
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: scripts/sh/link-input.sh <path> [name]" >&2
  exit 2
fi
if [[ ! -e $1 ]]; then
  echo "no such file or folder: $1" >&2
  exit 1
fi

target="$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"   # absolute, so the link works from anywhere
name=${2:-$(basename "$1")}
link="$root/data/$name"

if [[ $target == "$root"/* ]]; then
  echo "refusing: $target is inside the project; inputs should live outside it" >&2
  exit 1
fi
if [[ -e $link || -L $link ]]; then
  echo "data/$name already exists (-> $(readlink "$link" || echo '?')); choose another name or remove it first" >&2
  exit 1
fi

ln -s "$target" "$link"
echo "data/$name -> $target"
echo "next: scripts/sh/catalogue-data.sh, review metadata/auto_catalogue_data.tsv, copy it to metadata/catalogue_data.tsv"
