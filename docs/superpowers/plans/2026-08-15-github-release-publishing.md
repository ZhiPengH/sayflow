# SayFlow GitHub Release Publishing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish a clearly labeled `v1.3.4` GitHub Pre-release with a verified DMG and make future local releases a safe, one-command workflow for a beginner.

**Architecture:** Keep ordinary Git pushes separate from distribution. Centralize repository URLs and version metadata, place reusable shell validation in `release_common.sh`, and let `publish_release.sh` orchestrate test, package, tag, GitHub Release creation, asset upload, and read-back verification. Stable publication is denied unless Developer ID, Gatekeeper, and notarization checks all pass; the current local-signed package can only use the explicit prerelease path.

**Tech Stack:** Swift 5 / SwiftPM, Bash, macOS `codesign` / `spctl` / `stapler`, Git, GitHub CLI `gh`, GitHub Releases.

## Global Constraints

- `v1.3.4` is a GitHub Pre-release, not an Apple-notarized stable release.
- Never commit or print `.p12`, `.p8`, passwords, API keys, GitHub tokens, or local provider configuration.
- Keep `dist/` ignored; release assets are uploaded through GitHub Releases rather than Git commits.
- Preserve the unrelated untracked `.agents/` directory and never stage it.
- Ordinary `git push` must remain code-only; publishing requires an explicit release command.
- Stable publication requires Developer ID, Gatekeeper, and notarization verification.
- SHA-256 files must contain the DMG basename, never an absolute local path.
- Existing version floor remains macOS 13.0; the DMG remains Universal `arm64 + x86_64`.

---

### Task 1: Centralize the GitHub Release Repository

**Files:**
- Create: `Sources/SayFlowCore/ReleaseDistribution.swift`
- Create: `Tests/SayFlowCoreTests/ReleaseDistributionTests.swift`
- Modify: `Tests/SayFlowCoreTests/TestRunner.swift`
- Modify: `Sources/SayFlow/AppServices.swift`
- Modify: `Sources/SayFlowCore/Localization.swift`
- Modify: `Tests/SayFlowCoreTests/UpdateCheckerTests.swift`

**Interfaces:**
- Produces: `ReleaseDistribution.repositorySlug: String`
- Produces: `ReleaseDistribution.releasesPageURL: URL`
- Produces: `ReleaseDistribution.latestStableReleaseAPIURL: URL`
- Consumes: App update checks and localized About text use these values.

- [ ] **Step 1: Write the failing URL test**

```swift
import Foundation

enum ReleaseDistributionTests {
    static func pointsToCurrentPublicRepository() throws {
        try expectEqual(ReleaseDistribution.repositorySlug, "ZhiPengH/sayflow")
        try expectEqual(
            ReleaseDistribution.releasesPageURL.absoluteString,
            "https://github.com/ZhiPengH/sayflow/releases"
        )
        try expectEqual(
            ReleaseDistribution.latestStableReleaseAPIURL.absoluteString,
            "https://api.github.com/repos/ZhiPengH/sayflow/releases/latest"
        )
    }
}
```

Register it in `TestRunner.swift` as `Release distribution repository`.

- [ ] **Step 2: Run the test and confirm RED**

Run:

```bash
swiftc -swift-version 5 Sources/SayFlowCore/*.swift Tests/SayFlowCoreTests/*.swift -o .build/local-tests/SayFlowCoreTests
```

Expected: compilation fails because `ReleaseDistribution` does not exist.

- [ ] **Step 3: Add the minimal repository definition**

```swift
import Foundation

public enum ReleaseDistribution {
    public static let repositorySlug = "ZhiPengH/sayflow"
    public static let releasesPageURL = URL(string: "https://github.com/ZhiPengH/sayflow/releases")!
    public static let latestStableReleaseAPIURL = URL(
        string: "https://api.github.com/repos/ZhiPengH/sayflow/releases/latest"
    )!
}
```

Use `latestStableReleaseAPIURL` in `UpdateCheckService`, interpolate `releasesPageURL.absoluteString` into both About translations, and update the evaluator fixture to the current repository URL.

- [ ] **Step 4: Run the focused suite and confirm GREEN**

```bash
swiftc -swift-version 5 Sources/SayFlowCore/*.swift Tests/SayFlowCoreTests/*.swift -o .build/local-tests/SayFlowCoreTests
.build/local-tests/SayFlowCoreTests
```

Expected: all registered SayFlowCore tests pass and no product source contains `ZhiPengH/sayflow-release`.

- [ ] **Step 5: Commit the URL correction**

```bash
git add Sources/SayFlowCore/ReleaseDistribution.swift \
  Sources/SayFlow/AppServices.swift Sources/SayFlowCore/Localization.swift \
  Tests/SayFlowCoreTests/ReleaseDistributionTests.swift \
  Tests/SayFlowCoreTests/UpdateCheckerTests.swift Tests/SayFlowCoreTests/TestRunner.swift
git commit -m "fix: 修正 GitHub Release 更新入口"
```

---

### Task 2: Introduce a Single Version Source and Dynamic About Version

**Files:**
- Create: `VERSION`
- Modify: `Scripts/build_app.sh`
- Modify: `Scripts/package_dmg.sh`
- Modify: `Scripts/verify_package.sh`
- Modify: `Sources/SayFlowCore/Localization.swift`
- Modify: `Sources/SayFlow/SettingsWindow.swift`
- Modify: `Tests/SayFlowCoreTests/LocalizationTests.swift`
- Modify: `Scripts/test.sh`

**Interfaces:**
- Produces: root `VERSION` containing strict SemVer `1.3.4`.
- Produces: `L10n.aboutVersion(_ version: String, language: AppLanguage) -> String`.
- Consumes: all package scripts read `VERSION` unless the `VERSION` environment variable is explicitly supplied; Task 3 later moves the repeated validation into `release_common.sh`.

- [ ] **Step 1: Write failing localization and script expectations**

Add to `LocalizationTests.keyUiStringsHaveChineseAndEnglishTranslations()`:

```swift
try expectEqual(L10n.aboutVersion("9.8.7", language: .english), "Version 9.8.7")
try expectEqual(L10n.aboutVersion("9.8.7", language: .chinese), "版本 9.8.7")
```

Replace hard-coded script-version greps in `Scripts/test.sh` with:

```bash
test "$(cat VERSION)" = "1.3.4"
grep -q 'VERSION_FILE="$ROOT/VERSION"' Scripts/build_app.sh
grep -q 'VERSION_FILE="$ROOT/VERSION"' Scripts/package_dmg.sh
grep -q 'VERSION_FILE="$ROOT/VERSION"' Scripts/verify_package.sh
```

- [ ] **Step 2: Run the focused checks and confirm RED**

```bash
swiftc -swift-version 5 Sources/SayFlowCore/*.swift Tests/SayFlowCoreTests/*.swift -o .build/local-tests/SayFlowCoreTests
bash Scripts/test.sh
```

Expected: Swift compilation fails because `L10n.aboutVersion` is missing; shell checks fail because `VERSION` and `VERSION_FILE` reads are missing.

- [ ] **Step 3: Add the minimal implementation**

Create `VERSION` with:

```text
1.3.4
```

Add:

```swift
public static func aboutVersion(_ version: String, language: AppLanguage = .preferred()) -> String {
    String(format: tr(.aboutVersion, language: language), version)
}
```

Change the English and Chinese `.aboutVersion` translations to `Version %@` and `版本 %@`, and render `L10n.aboutVersion(CurrentApp.version)` in `SettingsWindow.aboutView()`.

Each shell entry point uses this direct read until Task 3 extracts the shared helper:

```bash
VERSION_FILE="$ROOT/VERSION"
VERSION="${VERSION:-$(tr -d '[:space:]' < "$VERSION_FILE")}"
```

- [ ] **Step 4: Run the focused checks and confirm GREEN**

```bash
swiftc -swift-version 5 Sources/SayFlowCore/*.swift Tests/SayFlowCoreTests/*.swift -o .build/local-tests/SayFlowCoreTests
.build/local-tests/SayFlowCoreTests
bash -n Scripts/build_app.sh Scripts/package_dmg.sh Scripts/verify_package.sh
```

Expected: Swift tests pass and shell syntax checks exit 0.

- [ ] **Step 5: Commit version centralization**

```bash
git add VERSION Scripts/build_app.sh Scripts/package_dmg.sh Scripts/verify_package.sh \
  Scripts/test.sh Sources/SayFlowCore/Localization.swift Sources/SayFlow/SettingsWindow.swift \
  Tests/SayFlowCoreTests/LocalizationTests.swift
git commit -m "refactor: 统一发布版本来源"
```

---

### Task 3: Add Tested Release Metadata Helpers

**Files:**
- Create: `Scripts/release_common.sh`
- Create: `Tests/ScriptTests/ReleaseCommonTests.sh`
- Modify: `Scripts/build_app.sh`
- Modify: `Scripts/package_dmg.sh`
- Modify: `Scripts/verify_package.sh`
- Modify: `Scripts/test.sh`

**Interfaces:**
- Produces: `sayflow_validate_version <version>`.
- Produces: `sayflow_read_version <repo-root>`.
- Produces: `sayflow_write_sha256 <absolute-artifact-path>`.
- Produces: `sayflow_stable_release_allowed <codesign-output> <spctl-status> <stapler-status>`.

- [ ] **Step 1: Write failing shell behavior tests**

The test script sources `release_common.sh` and checks:

```bash
sayflow_validate_version "1.3.4"
! sayflow_validate_version "v1.3.4"
! sayflow_validate_version "1.3"
test "$(sayflow_read_version "$fixture_root")" = "1.3.4"
sayflow_write_sha256 "$fixture_root/SayFlow-1.3.4.dmg"
grep -Eq '^[0-9a-f]{64}  SayFlow-1\.3\.4\.dmg$' "$fixture_root/SayFlow-1.3.4.dmg.sha256"
sayflow_stable_release_allowed "Authority=Developer ID Application: Example" 0 0
! sayflow_stable_release_allowed "Authority=SayFlow Local Development" 0 0
! sayflow_stable_release_allowed "Authority=Developer ID Application: Example" 1 0
! sayflow_stable_release_allowed "Authority=Developer ID Application: Example" 0 1
```

- [ ] **Step 2: Run and confirm RED**

```bash
bash Tests/ScriptTests/ReleaseCommonTests.sh
```

Expected: failure because `Scripts/release_common.sh` does not exist.

- [ ] **Step 3: Implement the minimal helpers**

Implement strict `^[0-9]+\.[0-9]+\.[0-9]+$` validation, trimmed `VERSION` reading, basename-only SHA generation from the artifact directory, and stable gating that requires a `Developer ID Application:` authority plus zero `spctl` and `stapler` statuses.

Source `release_common.sh` from all three package entry points, replace their direct reads with `sayflow_read_version "$ROOT"`, and replace the absolute-path SHA generation in `package_dmg.sh` with `sayflow_write_sha256 "$DMG"`. Add `Scripts/test.sh` checks that each entry point contains `sayflow_read_version`.

- [ ] **Step 4: Run and confirm GREEN**

```bash
bash Tests/ScriptTests/ReleaseCommonTests.sh
bash -n Scripts/*.sh Tests/ScriptTests/*.sh
```

Expected: both commands exit 0 and the fixture SHA file contains only the basename.

- [ ] **Step 5: Commit the helpers**

```bash
git add Scripts/release_common.sh Scripts/build_app.sh Scripts/package_dmg.sh \
  Scripts/verify_package.sh Scripts/test.sh \
  Tests/ScriptTests/ReleaseCommonTests.sh
git commit -m "test: 增加发布元数据安全门禁"
```

---

### Task 4: Implement the Beginner-Safe Publish Command

**Files:**
- Create: `Scripts/publish_release.sh`
- Create: `Tests/ScriptTests/PublishReleaseCLITests.sh`
- Modify: `Scripts/test.sh`

**Interfaces:**
- CLI: `Scripts/publish_release.sh --dry-run --prerelease`.
- CLI: `Scripts/publish_release.sh --prerelease` for a build-and-publish run.
- CLI: `Scripts/publish_release.sh --prerelease --use-existing-artifacts` for a previously rebuilt and freshly verified artifact.
- Stable default refuses publication until all Apple distribution checks pass.

- [ ] **Step 1: Write failing CLI tests**

```bash
help="$(Scripts/publish_release.sh --help)"
grep -q -- '--dry-run' <<<"$help"
grep -q -- '--prerelease' <<<"$help"
grep -q -- '--use-existing-artifacts' <<<"$help"

plan="$(Scripts/publish_release.sh --dry-run --prerelease)"
grep -q 'channel=prerelease' <<<"$plan"
grep -q 'tag=v1.3.4' <<<"$plan"
grep -q 'ordinary_push_publishes_dmg=false' <<<"$plan"
```

The test also confirms that dry-run does not create `v1.3.4` or a GitHub Release.

- [ ] **Step 2: Run and confirm RED**

```bash
bash Tests/ScriptTests/PublishReleaseCLITests.sh
```

Expected: exit 127 because `Scripts/publish_release.sh` does not exist.

- [ ] **Step 3: Implement the orchestration**

The script must:

```text
parse --help / --dry-run / --prerelease / --use-existing-artifacts
read and validate VERSION
print a no-mutation plan for --dry-run
require gh authentication and a tracked-clean worktree
fetch origin and prove HEAD is pushed
run Scripts/test.sh
run Scripts/package_dmg.sh unless --use-existing-artifacts was selected
run Scripts/verify_package.sh
inspect codesign, spctl and stapler results
refuse stable publication when any Apple distribution gate fails
create or safely reuse an annotated tag pointing to HEAD
push the current branch and tag
build bilingual notes with the prerelease warning
call gh release create with --prerelease and both assets
read the release JSON back and verify the two asset names and nonzero sizes
```

Never use `git add -A`, `--force`, `gh release upload --clobber`, or credential-printing commands.

- [ ] **Step 4: Run and confirm GREEN**

```bash
bash Tests/ScriptTests/PublishReleaseCLITests.sh
Scripts/publish_release.sh --dry-run --prerelease
```

Expected: tests pass; dry-run prints the exact version, tag, channel, asset paths, and no-mutation status.

- [ ] **Step 5: Commit the command**

```bash
git add Scripts/publish_release.sh Scripts/test.sh Tests/ScriptTests/PublishReleaseCLITests.sh
git commit -m "feat: 增加一键 GitHub Pre-release 发布"
```

---

### Task 5: Add Beginner Documentation and Download Entry Points

**Files:**
- Create: `docs/releasing-for-beginners.md`
- Modify: `README.md`
- Modify: `README.en.md`
- Modify: `CHANGLOG.md`

**Interfaces:**
- Produces: a public download link to `https://github.com/ZhiPengH/sayflow/releases`.
- Produces: a three-concept beginner guide for commit, push, and release.

- [ ] **Step 1: Add failing documentation checks**

Add to `Scripts/test.sh`:

```bash
grep -q 'github.com/ZhiPengH/sayflow/releases' README.md
grep -q 'github.com/ZhiPengH/sayflow/releases' README.en.md
grep -q '普通 push' docs/releasing-for-beginners.md
grep -q 'Scripts/publish_release.sh --prerelease' docs/releasing-for-beginners.md
```

- [ ] **Step 2: Run and confirm RED**

```bash
bash Scripts/test.sh
```

Expected: failure because the beginner guide and download sections do not exist.

- [ ] **Step 3: Write the minimal documentation**

README download sections must identify `v1.3.4` as a Pre-release and link to the Releases list. The beginner guide must explain:

```text
commit = 本机保存一次改动
push = 把 commit 同步到 GitHub，不上传 DMG
release = 带版本标签、说明和安装附件的下载页
```

Include the one-command flow, the SHA check command, the macOS “Privacy & Security → Open Anyway” path, and an explicit warning not to disable Gatekeeper globally.

Update the `v1.3.4` changelog entry to say the package is published as a local-signed, unnotarized Pre-release; replace the SHA after Task 6 produces the final artifact.

- [ ] **Step 4: Run documentation checks**

```bash
git diff --check
if rg -n 'sayflow-release' README.md README.en.md docs Sources Tests Scripts \
  --glob '!docs/superpowers/**'; then
  exit 1
fi
```

Expected: no whitespace errors and no old release-repository references outside historical migration material.

- [ ] **Step 5: Commit documentation**

```bash
git add README.md README.en.md CHANGLOG.md docs/releasing-for-beginners.md Scripts/test.sh
git commit -m "docs: 增加新手发布与安装说明"
```

---

### Task 6: Rebuild and Verify the Final v1.3.4 Artifact

**Files:**
- Modify: `CHANGLOG.md`
- Modify: `docs/acceptance-checklist.md`
- Modify: `docs/completion-audit.md`
- Generated but ignored: `dist/SayFlow-1.3.4.dmg`
- Generated but ignored: `dist/SayFlow-1.3.4.dmg.sha256`

**Interfaces:**
- Produces: the exact two assets uploaded to GitHub.
- Consumes: all source and release-script changes from Tasks 1–5.

- [ ] **Step 1: Run the full verification suite**

```bash
Scripts/test.sh
```

Expected: all SayFlowCore and script behavior tests pass, plus Release and Debug builds.

- [ ] **Step 2: Rebuild the package**

```bash
Scripts/package_dmg.sh
```

Expected: a Universal `dist/SayFlow-1.3.4.dmg` and basename-only `.sha256` file.

- [ ] **Step 3: Verify the package**

```bash
Scripts/verify_package.sh
(cd dist && shasum -a 256 -c SayFlow-1.3.4.dmg.sha256)
```

Expected: package verification and checksum verification pass. Record that `spctl` and `stapler` do not qualify it as stable.

- [ ] **Step 4: Synchronize final evidence**

Replace every v1.3.4 SHA in `CHANGLOG.md`, `docs/acceptance-checklist.md`, and `docs/completion-audit.md` with the freshly generated hash. Update test counts only from the fresh `Scripts/test.sh` output.

- [ ] **Step 5: Verify evidence and commit**

```bash
git diff --check
test "$(awk '{print $1}' dist/SayFlow-1.3.4.dmg.sha256)" = "$(shasum -a 256 dist/SayFlow-1.3.4.dmg | awk '{print $1}')"
git add CHANGLOG.md docs/acceptance-checklist.md docs/completion-audit.md
git commit -m "chore: 固化 v1.3.4 发布校验结果"
```

---

### Task 7: Push, Tag, Publish, and Verify GitHub UI

**Files:**
- No tracked source changes expected.
- Reads: `dist/SayFlow-1.3.4.dmg` and `.sha256`.

**Interfaces:**
- Produces: remote branch updates, annotated `v1.3.4` tag, GitHub Pre-release, two downloadable assets.

- [ ] **Step 1: Run final pre-publish checks**

```bash
git status -sb
git diff --check
Scripts/test.sh
Scripts/verify_package.sh
```

Expected: only unrelated `.agents/` remains untracked; every verification exits 0.

- [ ] **Step 2: Push tracked implementation commits**

```bash
git push -u origin codex/release-v1.3.4
```

Expected: the remote branch points to the final verified release commit.

- [ ] **Step 3: Publish through the tested command**

```bash
Scripts/publish_release.sh --prerelease --use-existing-artifacts
```

Expected: annotated tag `v1.3.4`, GitHub Pre-release, DMG, and SHA asset are created without force operations.

- [ ] **Step 4: Read back release evidence**

```bash
gh release view v1.3.4 --repo ZhiPengH/sayflow \
  --json tagName,isPrerelease,isDraft,targetCommitish,url,name,assets
```

Expected: `isPrerelease=true`, `isDraft=false`, and assets include exactly `SayFlow-1.3.4.dmg` and `SayFlow-1.3.4.dmg.sha256`, each with nonzero size.

- [ ] **Step 5: Open and inspect the Releases page**

Open `https://github.com/ZhiPengH/sayflow/releases/tag/v1.3.4` in the user's authenticated Chrome session. Confirm the warning, download instructions, checksum, and both assets are visible. Do not close user-owned tabs.

- [ ] **Step 6: Explain the result to the user**

Use this beginner mental model:

```text
改代码 → commit
同步代码 → push
给别人下载 → release
```

State that future ordinary pushes do not publish a DMG. Until Developer ID notarization exists, the approved command remains `Scripts/publish_release.sh --prerelease`; after Apple credentials are configured, add the tag-triggered cloud workflow as a separate reviewed change.
