#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: $0 <repository> <branch-name> <output-file>" >&2
  exit 1
fi

repository=$1
branch_name=$2
output_file=$3

repo_url="https://github.com/${repository}.git"
old_sha="$(git ls-remote "$repo_url" "refs/heads/${branch_name}" | awk '{print $1}')"

gh repo sync "$repository" -b "$branch_name"

new_sha="$(git ls-remote "$repo_url" "refs/heads/${branch_name}" | awk '{print $1}')"

if [[ -z "$old_sha" || -z "$new_sha" ]]; then
  echo "W: unable to resolve ${branch_name} SHA, conservatively trigger build"
  echo "should_build=true" >> "$output_file"
  exit 0
fi

if [[ "$old_sha" == "$new_sha" ]]; then
  echo "I: ${branch_name} unchanged, skip build"
  echo "should_build=false" >> "$output_file"
  exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

git -C "$tmpdir" init -q
git -C "$tmpdir" remote add origin "$repo_url"

if ! git -C "$tmpdir" fetch --no-tags --quiet origin "$branch_name"; then
  echo "W: fetch failed, conservatively trigger build"
  echo "should_build=true" >> "$output_file"
  exit 0
fi

if ! git -C "$tmpdir" rev-parse --verify "$old_sha" >/dev/null 2>&1; then
  echo "W: old SHA not found after fetch, conservatively trigger build"
  echo "should_build=true" >> "$output_file"
  exit 0
fi

if ! git -C "$tmpdir" rev-parse --verify "$new_sha" >/dev/null 2>&1; then
  echo "W: new SHA not found after fetch, conservatively trigger build"
  echo "should_build=true" >> "$output_file"
  exit 0
fi

if git -C "$tmpdir" diff --name-only "$old_sha" "$new_sha" -- docker/ | grep -q .; then
  echo "I: docker/ changed, trigger build"
  echo "should_build=true" >> "$output_file"
else
  echo "I: no docker/ changes, skip build"
  echo "should_build=false" >> "$output_file"
fi
