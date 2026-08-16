#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

REAL_GIT="$(command -v git)"
FAKE_BIN="$(mktemp -d "${TMPDIR:-/tmp}/sayflow-publish-cli.XXXXXX")"
COMMAND_LOG="$FAKE_BIN/commands.log"
cleanup() {
  rm -rf "$FAKE_BIN"
}
trap cleanup EXIT

for command_name in git gh; do
  cat >"$FAKE_BIN/$command_name" <<EOF
#!/usr/bin/env bash
printf '%s\\n' '$command_name' >>'$COMMAND_LOG'
exit 97
EOF
  chmod +x "$FAKE_BIN/$command_name"
done

help="$(Scripts/publish_release.sh --help)"
grep -q -- '--dry-run' <<<"$help"
grep -q -- '--prerelease' <<<"$help"
grep -q -- '--use-existing-artifacts' <<<"$help"

tag_before="$("$REAL_GIT" rev-parse --verify --quiet refs/tags/v1.3.6 || true)"
plan="$(PATH="$FAKE_BIN:$PATH" Scripts/publish_release.sh --dry-run --prerelease)"
tag_after="$("$REAL_GIT" rev-parse --verify --quiet refs/tags/v1.3.6 || true)"

grep -q 'channel=prerelease' <<<"$plan"
grep -q 'tag=v1.3.6' <<<"$plan"
grep -q 'ordinary_push_publishes_dmg=false' <<<"$plan"
[[ "$tag_after" == "$tag_before" ]]
[[ ! -e "$COMMAND_LOG" ]]

existing_plan="$(PATH="$FAKE_BIN:$PATH" Scripts/publish_release.sh --dry-run --prerelease --use-existing-artifacts)"
grep -q 'package=0' <<<"$existing_plan"
grep -q 'verify=true' <<<"$existing_plan"
[[ ! -e "$COMMAND_LOG" ]]

printf 'PASS publish release CLI help and dry-run\n'
