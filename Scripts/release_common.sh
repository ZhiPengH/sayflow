#!/usr/bin/env bash

sayflow_validate_version() {
  local version="${1:-}"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

sayflow_read_version() {
  local repo_root="$1"
  local version

  version="$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$repo_root/VERSION")"
  if ! sayflow_validate_version "$version"; then
    echo "Invalid VERSION: $version" >&2
    return 1
  fi
  printf '%s\n' "$version"
}

sayflow_write_sha256() {
  local artifact_path="$1"
  local artifact_dir artifact_name checksum

  [[ "$artifact_path" == /* ]] || {
    echo "Artifact path must be absolute: $artifact_path" >&2
    return 1
  }
  artifact_dir="$(dirname "$artifact_path")"
  artifact_name="$(basename "$artifact_path")"
  checksum="$(cd "$artifact_dir" && shasum -a 256 "$artifact_name" | awk '{print $1}')"
  printf '%s  %s\n' "$checksum" "$artifact_name" > "$artifact_path.sha256"
}

sayflow_stable_release_allowed() {
  local codesign_output="$1"
  local spctl_status="$2"
  local stapler_status="$3"

  grep -F 'Authority=Developer ID Application:' <<<"$codesign_output" >/dev/null &&
    [[ "$spctl_status" == "0" ]] &&
    [[ "$stapler_status" == "0" ]]
}
