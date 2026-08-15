#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/Scripts/release_common.sh"

usage() {
  cat <<'EOF'
Usage: Scripts/publish_release.sh [--dry-run] [--prerelease] [--use-existing-artifacts]

Build, verify, and publish the version in VERSION as a GitHub Release.

Options:
  --dry-run                 Print the release plan without making changes.
  --prerelease              Publish to the GitHub prerelease channel.
  --use-existing-artifacts  Skip packaging and verify the existing artifacts.
  -h, --help                Show this help message.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_tracked_clean_worktree() {
  local status
  status="$(git status --porcelain --untracked-files=no)"
  [[ -z "$status" ]] || die "Tracked files have uncommitted changes. Commit or restore them before publishing."
}

asset_has_nonzero_size() {
  local expected_name="$1"
  awk -F '\t' -v expected_name="$expected_name" '
    $1 == expected_name && $2 ~ /^[0-9]+$/ && $2 + 0 > 0 { found = 1 }
    END { exit(found ? 0 : 1) }
  '
}

dry_run=0
prerelease=0
use_existing_artifacts=0

while (($#)); do
  case "$1" in
    --dry-run)
      dry_run=1
      ;;
    --prerelease)
      prerelease=1
      ;;
    --use-existing-artifacts)
      use_existing_artifacts=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

VERSION="$(sayflow_read_version "$ROOT")"
TAG="v$VERSION"
DMG="$ROOT/dist/SayFlow-$VERSION.dmg"
SHA256="$DMG.sha256"
CHANNEL="stable"
if ((prerelease)); then
  CHANNEL="prerelease"
fi

if ((dry_run)); then
  printf 'version=%s\n' "$VERSION"
  printf 'tag=%s\n' "$TAG"
  printf 'channel=%s\n' "$CHANNEL"
  printf 'dmg=%s\n' "$DMG"
  printf 'sha256=%s\n' "$SHA256"
  printf 'package=%s\n' "$((1 - use_existing_artifacts))"
  printf 'verify=true\n'
  printf 'ordinary_push_publishes_dmg=false\n'
  printf 'no_mutation=true\n'
  exit 0
fi

cd "$ROOT"

for required_command in git gh codesign spctl xcrun; do
  require_command "$required_command"
done

require_tracked_clean_worktree
git remote get-url origin >/dev/null 2>&1 || die "Git remote 'origin' is not configured."
gh auth status >/dev/null 2>&1 || die "GitHub CLI authentication is required. Run 'gh auth login' first."
gh repo view --json nameWithOwner >/dev/null 2>&1 ||
  die "GitHub CLI cannot access the repository resolved from origin."

BRANCH="$(git symbolic-ref --quiet --short HEAD)" || die "Publishing from a detached HEAD is not allowed."
HEAD_COMMIT="$(git rev-parse HEAD)"

git fetch --prune --tags origin >/dev/null 2>&1 || die "Failed to fetch origin."
require_tracked_clean_worktree

UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" ||
  die "The current branch must have an upstream on origin."
[[ "$UPSTREAM" == "origin/$BRANCH" ]] ||
  die "The current branch must track origin/$BRANCH (found $UPSTREAM)."
REMOTE_HEAD="$(git rev-parse "$UPSTREAM")"
[[ "$HEAD_COMMIT" == "$REMOTE_HEAD" ]] ||
  die "HEAD is not exactly pushed to $UPSTREAM. Push or synchronize the branch first."

"$ROOT/Scripts/test.sh"
if ((!use_existing_artifacts)); then
  VERSION="$VERSION" "$ROOT/Scripts/package_dmg.sh"
fi
VERSION="$VERSION" "$ROOT/Scripts/verify_package.sh"

require_tracked_clean_worktree
[[ "$(git rev-parse HEAD)" == "$HEAD_COMMIT" ]] ||
  die "HEAD changed while preparing the release. Start again from the pushed commit."
[[ -s "$DMG" ]] || die "Release asset is missing or empty: $DMG"
[[ -s "$SHA256" ]] || die "Release asset is missing or empty: $SHA256"

APP="$ROOT/dist/SayFlow.app"
codesign_status=0
codesign_details=""
if codesign_details="$(codesign -dv --verbose=4 "$APP" 2>&1)"; then
  :
else
  codesign_status=$?
fi

spctl_status=0
if spctl --assess --type execute --verbose=4 "$APP" >/dev/null 2>&1; then
  :
else
  spctl_status=$?
fi

stapler_status=0
if xcrun stapler validate "$DMG" >/dev/null 2>&1; then
  :
else
  stapler_status=$?
fi

apple_distribution_ready=0
if [[ "$codesign_status" == "0" ]] &&
  sayflow_stable_release_allowed "$codesign_details" "$spctl_status" "$stapler_status"; then
  apple_distribution_ready=1
fi
printf 'apple_codesign_status=%s\n' "$codesign_status"
printf 'apple_spctl_status=%s\n' "$spctl_status"
printf 'apple_stapler_status=%s\n' "$stapler_status"

if ((!prerelease && !apple_distribution_ready)); then
  die "Stable publication requires Developer ID signing, Gatekeeper acceptance, and a valid stapled notarization ticket."
fi
if ((prerelease && !apple_distribution_ready)); then
  echo "WARNING: Apple distribution checks are incomplete; continuing only because --prerelease was selected." >&2
fi

RELEASE_LOOKUP_ERROR="$(mktemp "${TMPDIR:-/tmp}/sayflow-release-lookup.XXXXXX")"
NOTES_FILE=""
cleanup() {
  rm -f "$RELEASE_LOOKUP_ERROR"
  if [[ -n "$NOTES_FILE" ]]; then
    rm -f "$NOTES_FILE"
  fi
}
trap cleanup EXIT

if gh release view "$TAG" --json tagName >/dev/null 2>"$RELEASE_LOOKUP_ERROR"; then
  die "GitHub Release $TAG already exists; refusing to overwrite it."
elif ! grep -Eiq 'release not found|not found|HTTP 404' "$RELEASE_LOOKUP_ERROR"; then
  die "Could not safely prove that GitHub Release $TAG does not exist."
fi

if git show-ref --verify --quiet "refs/tags/$TAG"; then
  [[ "$(git cat-file -t "refs/tags/$TAG")" == "tag" ]] ||
    die "Existing tag $TAG is lightweight; an annotated release tag is required."
  TAG_COMMIT="$(git rev-parse "refs/tags/$TAG^{}")"
  [[ "$TAG_COMMIT" == "$HEAD_COMMIT" ]] ||
    die "Existing tag $TAG points to $TAG_COMMIT, not HEAD $HEAD_COMMIT."
else
  git tag -a "$TAG" -m "SayFlow $VERSION"
fi

git push origin "refs/heads/$BRANCH:refs/heads/$BRANCH" >/dev/null 2>&1 ||
  die "Failed to push branch $BRANCH to origin."
git push origin "refs/tags/$TAG:refs/tags/$TAG" >/dev/null 2>&1 ||
  die "Failed to push tag $TAG to origin."
REMOTE_TAG_COMMIT="$(git ls-remote origin "refs/tags/$TAG^{}" 2>/dev/null | awk 'NR == 1 { print $1 }')"
[[ "$REMOTE_TAG_COMMIT" == "$HEAD_COMMIT" ]] ||
  die "Remote tag $TAG does not resolve exactly to HEAD $HEAD_COMMIT."

NOTES_FILE="$(mktemp "${TMPDIR:-/tmp}/sayflow-release-notes.XXXXXX")"
if ((prerelease)); then
  {
    printf '# SayFlow %s 预发布 / Prerelease\n\n' "$VERSION"
    printf '⚠️ 这是预发布版本，Apple 公证或分发检查可能尚未全部完成，请仅用于测试。\n\n'
    printf '⚠️ This is a prerelease. Apple notarization or distribution checks may be incomplete; use it for testing only.\n\n'
    printf '下载 DMG 后，请使用随附的 SHA-256 文件校验完整性。\n\n'
    printf 'Verify the downloaded DMG with the included SHA-256 checksum file.\n'
  } >"$NOTES_FILE"
else
  {
    printf '# SayFlow %s 正式版 / Stable Release\n\n' "$VERSION"
    printf '此版本已通过发布流程中的 Apple 分发检查。\n\n'
    printf 'This release passed the Apple distribution checks in the publishing workflow.\n\n'
    printf '下载 DMG 后，请使用随附的 SHA-256 文件校验完整性。\n\n'
    printf 'Verify the downloaded DMG with the included SHA-256 checksum file.\n'
  } >"$NOTES_FILE"
fi

release_arguments=(
  release create "$TAG"
  "$DMG"
  "$SHA256"
  --title "SayFlow $VERSION"
  --notes-file "$NOTES_FILE"
  --verify-tag
)
if ((prerelease)); then
  release_arguments+=(--prerelease)
fi
gh "${release_arguments[@]}"

published_tag="$(gh release view "$TAG" --json tagName --jq '.tagName')"
[[ "$published_tag" == "$TAG" ]] ||
  die "GitHub Release readback returned tag '$published_tag', expected '$TAG'."
asset_rows="$(gh release view "$TAG" --json assets --jq '.assets[] | [.name, (.size | tostring)] | @tsv')"
asset_has_nonzero_size "$(basename "$DMG")" <<<"$asset_rows" ||
  die "GitHub Release is missing a nonempty $(basename "$DMG") asset."
asset_has_nonzero_size "$(basename "$SHA256")" <<<"$asset_rows" ||
  die "GitHub Release is missing a nonempty $(basename "$SHA256") asset."

printf 'Published and verified GitHub Release %s (%s).\n' "$TAG" "$CHANNEL"
