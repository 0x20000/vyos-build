#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <source-root> [patch-root]" >&2
  exit 1
fi

source_root=$1
patch_root=${2:-patches}

if [[ ! -d "$source_root" ]]; then
  echo "E: source root not found: $source_root" >&2
  exit 1
fi

if [[ ! -d "$patch_root" ]]; then
  echo "I: patch root not found: $patch_root, nothing to apply"
  exit 0
fi

found=0
while IFS= read -r -d '' patch_file; do
  found=1
  echo "I: applying $patch_file"
  git -C "$source_root" apply --check "$patch_file"
  git -C "$source_root" apply "$patch_file"
done < <(find "$patch_root" -type f \( -name '*.patch' -o -name '*.diff' \) -print0 | sort -z)

if [[ $found -eq 0 ]]; then
  echo "I: no patch files found under $patch_root"
fi