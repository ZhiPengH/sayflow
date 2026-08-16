#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

REAL_SHASUM="$(command -v shasum)"
FAKE_BIN="$(mktemp -d "${TMPDIR:-/tmp}/sayflow-ship-cli.XXXXXX")"
FIXTURE_DIST="$(mktemp -d "${TMPDIR:-/tmp}/sayflow-ship-dist.XXXXXX")"
COMMAND_LOG="$FAKE_BIN/commands.log"
cleanup() {
  rm -rf "$FAKE_BIN" "$FIXTURE_DIST"
}
trap cleanup EXIT

for command_name in git gh stapler; do
  cat >"$FAKE_BIN/$command_name" <<EOF
#!/usr/bin/env bash
printf '%s\n' '$command_name' >>'$COMMAND_LOG'
exit 97
EOF
  chmod +x "$FAKE_BIN/$command_name"
done

version="$(cat VERSION)"
dmg_name="SayFlow-$version.dmg"
printf 'fixture-dmg-bytes\n' >"$FIXTURE_DIST/$dmg_name"
checksum="$(cd "$FIXTURE_DIST" && "$REAL_SHASUM" -a 256 "$dmg_name" | awk '{print $1}')"
printf '%s  %s\n' "$checksum" "$dmg_name" >"$FIXTURE_DIST/$dmg_name.sha256"

help="$(PATH="$FAKE_BIN:$PATH" DIST="$FIXTURE_DIST" Scripts/ship_release.sh --help)"
grep -q -- '--dry-run' <<<"$help"

plan="$(PATH="$FAKE_BIN:$PATH" DIST="$FIXTURE_DIST" Scripts/ship_release.sh --dry-run)"
grep -q "version=$version" <<<"$plan"
grep -q "tag=v$version" <<<"$plan"
grep -q "dmg=$FIXTURE_DIST/$dmg_name" <<<"$plan"
grep -q 'dmg_checksum=ok' <<<"$plan"
grep -q "ship_branch=codex/ship-v$version" <<<"$plan"
grep -q 'publish_command=Scripts/publish_release.sh --use-existing-artifacts' <<<"$plan"
grep -q 'no_mutation=true' <<<"$plan"
[[ ! -e "$COMMAND_LOG" ]] || exit 1

printf 'deadbeef00000000000000000000000000000000000000000000000000000000  %s\n' "$dmg_name" >"$FIXTURE_DIST/$dmg_name.sha256"
set +e
PATH="$FAKE_BIN:$PATH" DIST="$FIXTURE_DIST" Scripts/ship_release.sh --dry-run >"$FAKE_BIN/tampered-output" 2>&1
status=$?
set -e
[[ "$status" == "1" ]] || exit 1
grep -q 'checksum mismatch' "$FAKE_BIN/tampered-output" || exit 1
[[ ! -e "$COMMAND_LOG" ]] || exit 1

printf 'PASS ship release CLI dry-run and checksum gate\n'
