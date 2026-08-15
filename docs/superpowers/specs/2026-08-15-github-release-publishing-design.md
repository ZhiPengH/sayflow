# SayFlow GitHub Release 发布设计

日期：2026-08-15
状态：已获用户口头批准，等待书面复核

## 1. 目标

本次工作解决两个彼此关联的问题：

1. 让 `ZhiPengH/sayflow` 的 GitHub Releases 页面出现可下载的 `v1.3.4` DMG 和 SHA-256 校验文件；
2. 把以后容易遗漏的“测试、打包、校验、标签、push、创建 Release、上传附件”收敛为一个适合新手的一键流程。

同时修正 App 内仍指向已不存在的 `ZhiPengH/sayflow-release` 的更新检查和 About 页面链接。

## 2. 已确认的现状

- `dist/` 被 `.gitignore` 忽略，因此普通 `git push` 不会上传 DMG；这个忽略规则保留不变。
- GitHub Release 是独立于 commit 的发布对象，必须基于 tag 创建并显式上传附件。
- 当前远程最新 tag 是 `v1.3.3`，仓库还没有 `v1.3.4` tag，也没有任何 GitHub Release。
- `v1.3.4` 代码目前位于 `codex/release-v1.3.4`，PR #1 尚未合并。
- 当前 DMG 是 Universal `arm64 + x86_64`，本地结构、签名和内容校验已通过。
- 当前签名身份是自建的 `SayFlow Local Development`，没有 Apple Team ID、Developer ID 或 notarization ticket；Gatekeeper 会拒绝把它视为 Apple 已验证的软件。

## 3. 发布策略

### 3.1 普通 push

普通 `git push` 只同步源码和 Git 历史，不创建安装包，也不修改 GitHub Releases。这样可以避免把每个开发中间状态误发给用户。

### 3.2 正式发布动作

正式发布由 `Scripts/publish_release.sh` 统一执行：

```text
读取 VERSION
  → 检查 Git、GitHub 登录与远程状态
  → 运行完整测试
  → 构建 Universal DMG
  → 校验签名、架构、内容和 SHA-256
  → 判断是否满足稳定版签名门槛
  → 创建并 push vX.Y.Z tag
  → 创建 GitHub Release
  → 上传 DMG 与 .sha256
  → 回读 GitHub Release 验证附件
```

脚本支持：

- `--dry-run`：只展示将要执行的步骤，不创建 tag、Release 或附件；
- `--prerelease`：允许发布未通过 Apple notarization 的测试版，并强制加入风险说明；
- 默认稳定版：必须同时通过 Developer ID、Gatekeeper 和 notarization 验证，否则拒绝发布。

### 3.3 当前 v1.3.4

`v1.3.4` 以 **Pre-release** 发布。页面必须明确说明：

- 安装包是本地自签名、未 notarized 的测试构建；
- macOS 会显示“无法验证开发者”或安全拦截；
- 用户可以在首次打开失败后前往“系统设置 → 隐私与安全性”，仅对 SayFlow 选择“仍要打开”；
- 不建议关闭系统级 Gatekeeper，也不提供全局绕过命令。

Pre-release 不会被 GitHub 的 `/releases/latest` API 当作稳定版，因此现有用户的自动更新检查不会把该测试版主动推送给所有人。

## 4. 代码与文档改动

### 4.1 单一版本来源

新增根目录 `VERSION`，内容为 `1.3.4`。构建、打包和验证脚本默认从该文件读取版本号，避免以后在多个脚本中漏改。

About 页面显示的版本改为读取 App 的 `CFBundleShortVersionString`，不再把版本号写死在本地化文案里。

### 4.2 Release 地址

在 `SayFlowCore` 中提供唯一的 Release 仓库配置：

- 页面：`https://github.com/ZhiPengH/sayflow/releases`
- 最新稳定版 API：`https://api.github.com/repos/ZhiPengH/sayflow/releases/latest`

App 更新检查、About 页面和相关测试都使用或验证这个配置。旧的 `sayflow-release` 地址不得继续出现在产品代码中。

### 4.3 发布助手

新增 `Scripts/publish_release.sh`，安全约束如下：

- 只接受严格的 `X.Y.Z` 版本；
- 发布前要求 tracked working tree 干净；不接管或删除无关的 untracked 文件；
- 要求当前 commit 已经 push 到远程；
- tag 不存在时创建 annotated tag；tag 已存在但指向其他 commit 时停止；
- 所有本地门禁通过后才 push tag；
- tag 已正确存在而 Release 尚未创建时允许安全续跑；
- Release 已存在时不静默覆盖附件；
- 上传完成后通过 GitHub API 回读并核对 DMG、SHA 文件和大小；
- 不读取、输出或提交证书私钥、Apple API Key、GitHub token。

当前 `v1.3.4` 可以从公开的发布分支 commit 创建 Pre-release；以后稳定版默认要求 release commit 已进入 `main`。

### 4.4 SHA-256 文件

`.sha256` 文件只写 DMG 的文件名，不写本机绝对路径。下载两个附件后，用户可以直接运行：

```bash
shasum -a 256 -c SayFlow-1.3.4.dmg.sha256
```

### 4.5 新手文档和仓库首页

新增 `docs/releasing-for-beginners.md`，用三个概念解释 GitHub：

- commit：一次本地存档；
- push：把 commit 同步到 GitHub；
- release：给用户下载的版本页，包含 tag、说明和安装包。

README 中增加“下载安装”入口，并明确当前下载是 Pre-release。稳定版出现前不使用会忽略 Pre-release 的 `/releases/latest` 作为唯一入口。

## 5. 测试与验收

实现遵循 Red → Green：

1. 先为唯一 Release URL、动态 About 版本和版本文件读取补充失败测试；
2. 先为发布助手的版本校验、dry-run、stable 拒绝门槛和 prerelease 路径补充 shell 行为测试；
3. 确认测试因功能缺失而失败后，再写最小实现；
4. 运行 `Scripts/test.sh`；
5. 重新运行 `Scripts/package_dmg.sh` 和 `Scripts/verify_package.sh`；
6. 重新计算并核对 DMG SHA-256；
7. 创建 Pre-release 后，用 GitHub API 回读：tag、目标 commit、prerelease 状态、附件名称、附件大小和下载 URL；
8. 最后在用户的 GitHub Releases 页面中打开新版本，确认页面可见且附件可下载。

## 6. 失败处理

- 测试、构建或验证失败：不创建 tag，不发布。
- tag push 成功但 Release 创建失败：保留 tag，修复后续跑，不重写 tag。
- GitHub 身份确认失败：保留本地 DMG 和 commit，停止外部写入。
- 附件回读不一致：报告实际状态，不宣称发布完成，也不静默覆盖已有附件。
- 剪贴板、API Key、证书和本地配置不属于发布附件，任何时候都不得上传。

## 7. 暂不包含的范围

- 不在每次普通 push 时发布 DMG；
- 不把本地自签名包标记为稳定版；
- 不把 `.p12`、`.p8` 或密码写入仓库；
- 不在本次工作中购买或代办 Apple Developer Program；
- 不在没有 Developer ID 与 notarization 凭据时伪造“全云端正式发布”。

等用户具备 Apple Developer ID 后，再新增 tag 触发的 GitHub Actions：导入加密 secrets、Hardened Runtime 签名、notarytool 提交、stapler、Gatekeeper 验证，并在 release Environment 中保留人工批准门。
