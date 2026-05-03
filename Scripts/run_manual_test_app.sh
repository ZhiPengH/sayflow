#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-$("$ROOT/Scripts/ensure_codesign_identity.sh")}"
export CODESIGN_IDENTITY

"$ROOT/Scripts/build_app.sh" >/tmp/graker-manual-test-build.log
open "$ROOT/dist/Graker.app"
