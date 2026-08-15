#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE_ROOT="$(mktemp -d)"

trap 'status=$?; rm -rf "$FIXTURE_ROOT"; exit "$status"' EXIT

test -f "$ROOT/Scripts/release_common.sh"
source "$ROOT/Scripts/release_common.sh"

mkdir -p "$FIXTURE_ROOT/bin"
printf '%s\n' '#!/usr/bin/env bash' 'touch "$SAYFLOW_TEST_RM_MARKER"' 'exit 99' > "$FIXTURE_ROOT/bin/rm"
chmod +x "$FIXTURE_ROOT/bin/rm"

assert_invalid_version_override() {
  local entry_point="$1"
  local status

  rm -f "$FIXTURE_ROOT/reached-rm"
  set +e
  PATH="$FIXTURE_ROOT/bin:$PATH" \
    SAYFLOW_TEST_RM_MARKER="$FIXTURE_ROOT/reached-rm" \
    VERSION=v1.3.4 \
    CODESIGN_IDENTITY=- \
    "$ROOT/$entry_point" > "$FIXTURE_ROOT/entry-point-output" 2>&1
  status=$?
  set -e

  [[ "$status" == "1" ]]
  grep -F 'Invalid release version: v1.3.4' "$FIXTURE_ROOT/entry-point-output" >/dev/null
  [[ ! -e "$FIXTURE_ROOT/reached-rm" ]]
}

printf '1.3.4\n' > "$FIXTURE_ROOT/VERSION"
touch "$FIXTURE_ROOT/SayFlow-1.3.4.dmg"

sayflow_validate_version "1.3.4"
! sayflow_validate_version "v1.3.4"
! sayflow_validate_version "1.3"
test "$(sayflow_read_version "$FIXTURE_ROOT")" = "1.3.4"
printf '1. 3.4\n' > "$FIXTURE_ROOT/VERSION"
! sayflow_read_version "$FIXTURE_ROOT" >/dev/null 2>&1
printf '1.3.4\n' > "$FIXTURE_ROOT/VERSION"
sayflow_write_sha256 "$FIXTURE_ROOT/SayFlow-1.3.4.dmg"
grep -Eq '^[0-9a-f]{64}  SayFlow-1\.3\.4\.dmg$' "$FIXTURE_ROOT/SayFlow-1.3.4.dmg.sha256"
sayflow_stable_release_allowed "Authority=Developer ID Application: Example" 0 0
! sayflow_stable_release_allowed "Authority=SayFlow Local Development" 0 0
! sayflow_stable_release_allowed "Authority=Developer ID Application: Example" 1 0
! sayflow_stable_release_allowed "Authority=Developer ID Application: Example" 0 1
assert_invalid_version_override "Scripts/build_app.sh"
assert_invalid_version_override "Scripts/package_dmg.sh"
assert_invalid_version_override "Scripts/verify_package.sh"
assert_invalid_version_override "Scripts/notarize_release.sh"
