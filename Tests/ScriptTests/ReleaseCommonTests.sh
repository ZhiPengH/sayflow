#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE_ROOT="$(mktemp -d)"

trap 'status=$?; rm -rf "$FIXTURE_ROOT"; exit "$status"' EXIT

test -f "$ROOT/Scripts/release_common.sh"
source "$ROOT/Scripts/release_common.sh"

printf '1.3.4\n' > "$FIXTURE_ROOT/VERSION"
touch "$FIXTURE_ROOT/SayFlow-1.3.4.dmg"

sayflow_validate_version "1.3.4"
! sayflow_validate_version "v1.3.4"
! sayflow_validate_version "1.3"
test "$(sayflow_read_version "$FIXTURE_ROOT")" = "1.3.4"
sayflow_write_sha256 "$FIXTURE_ROOT/SayFlow-1.3.4.dmg"
grep -Eq '^[0-9a-f]{64}  SayFlow-1\.3\.4\.dmg$' "$FIXTURE_ROOT/SayFlow-1.3.4.dmg.sha256"
sayflow_stable_release_allowed "Authority=Developer ID Application: Example" 0 0
! sayflow_stable_release_allowed "Authority=SayFlow Local Development" 0 0
! sayflow_stable_release_allowed "Authority=Developer ID Application: Example" 1 0
! sayflow_stable_release_allowed "Authority=Developer ID Application: Example" 0 1
