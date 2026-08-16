#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/Scripts/release_common.sh"

REPO_SLUG="ZhiPengH/sayflow"

usage() {
  cat <<'EOF'
Usage: Scripts/ship_release.sh [--dry-run]

Ship the manually tested, notarized DMG in dist/ as the official GitHub
Release. Run Scripts/notarize_release.sh and finish manual testing first.

Options:
  --dry-run  Print the shipping plan without making changes.
  -h, --help Show this help message.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

dry_run=0
while (($#)); do
  case "$1" in
    --dry-run)
      dry_run=1
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
DIST="${DIST:-$ROOT/dist}"
DMG="$DIST/SayFlow-$VERSION.dmg"
SHA_FILE="$DMG.sha256"
SHIP_BRANCH="codex/ship-v$VERSION"

[[ -s "$DMG" ]] || die "Notarized DMG missing or empty: $DMG"
[[ -s "$SHA_FILE" ]] || die "DMG checksum file missing: $SHA_FILE"
expected_sha="$(awk '{print $1}' "$SHA_FILE")"
actual_sha="$(shasum -a 256 "$DMG" | awk '{print $1}')"
[[ "$expected_sha" == "$actual_sha" ]] ||
  die "DMG checksum mismatch: expected $expected_sha, got $actual_sha"

if ((dry_run)); then
  printf 'version=%s\n' "$VERSION"
  printf 'tag=%s\n' "$TAG"
  printf 'dmg=%s\n' "$DMG"
  printf 'dmg_checksum=ok\n'
  printf 'ship_branch=%s\n' "$SHIP_BRANCH"
  printf 'publish_command=Scripts/publish_release.sh --use-existing-artifacts\n'
  printf 'no_mutation=true\n'
  exit 0
fi

cd "$ROOT"

for required_command in git gh codesign spctl xcrun; do
  command -v "$required_command" >/dev/null 2>&1 ||
    die "Required command not found: $required_command"
done

STAPLER="$(sayflow_find_xcode_tool stapler)" ||
  die "stapler not found. Install Xcode and launch it once."

git_status="$(git status --porcelain --untracked-files=no)"
[[ -z "$git_status" ]] || die "Tracked files have uncommitted changes. Commit or restore them before shipping."

git remote get-url origin >/dev/null 2>&1 || die "Git remote 'origin' is not configured."
gh auth status >/dev/null 2>&1 || die "GitHub CLI authentication is required. Run 'gh auth login' first."
gh repo view "$REPO_SLUG" --json nameWithOwner >/dev/null 2>&1 ||
  die "GitHub CLI cannot access $REPO_SLUG."

echo "==> Validate notarization ticket on the tested DMG"
"$STAPLER" validate "$DMG"

git fetch --prune origin >/dev/null 2>&1 || die "Failed to fetch origin."

HEAD_COMMIT="$(git rev-parse HEAD)"
REMOTE_MAIN="$(git rev-parse origin/main)"

if git merge-base --is-ancestor "$HEAD_COMMIT" "$REMOTE_MAIN"; then
  echo "==> Release commit is already on origin/main; skipping PR"
else
  echo "==> Push $SHIP_BRANCH and merge via PR"
  git push origin "HEAD:refs/heads/$SHIP_BRANCH" >/dev/null ||
    die "Failed to push $SHIP_BRANCH."
  pr_state="NONE"
  if gh pr view "$SHIP_BRANCH" --repo "$REPO_SLUG" --json state >/dev/null 2>&1; then
    pr_state="$(gh pr view "$SHIP_BRANCH" --repo "$REPO_SLUG" --json state --jq '.state')"
  else
    gh pr create --repo "$REPO_SLUG" --base main --head "$SHIP_BRANCH" \
      --title "Release SayFlow $VERSION" \
      --body "Ship the manually tested v$VERSION notarized build." >/dev/null ||
      die "Failed to create the release PR."
  fi
  if [[ "$pr_state" != "MERGED" ]]; then
    gh pr merge "$SHIP_BRANCH" --repo "$REPO_SLUG" --admin --merge >/dev/null ||
      die "Failed to merge the release PR."
  fi
fi

echo "==> Sync local main to origin/main"
CURRENT_BRANCH="$(git symbolic-ref --quiet --short HEAD)" || die "Detached HEAD is not allowed."
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  git checkout main --quiet
fi
git pull --ff-only --quiet ||
  die "Failed to fast-forward local main to origin/main."

echo "==> Publish GitHub Release via publish_release.sh"
VERSION="$VERSION" "$ROOT/Scripts/publish_release.sh" --use-existing-artifacts

printf 'Shipped %s. Release: https://github.com/%s/releases/tag/%s\n' "$VERSION" "$REPO_SLUG" "$TAG"
