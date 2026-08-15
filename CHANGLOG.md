# CHANGLOG

This file follows the requested name, `CHANGLOG.md`. The missing "E" has the smell of an old project drawer: once a name is chosen, we keep it steady and make the content worthy of it.

这个文件按要求命名为 `CHANGLOG.md`。少掉的那个 "E"，倒有点老项目抽屉里的味道：名字一旦定下，就把内容写扎实。

## 2026-08-16

### Release v1.3.5

English:

- Promoted SayFlow from self-signed pre-release builds to an official Developer ID distribution: the app is signed with Developer ID Application: ZHIPENG HUANG (UTZUZ8U2J2), enables Hardened Runtime (flags=0x10000(runtime)), and carries a secure Apple timestamp.
- Added Scripts/notarize_release.sh: it builds the signed app, verifies the Developer ID authority, secure timestamp, and runtime flags, notarizes the app with notarytool, staples the ticket, requires Gatekeeper source=Notarized Developer ID, then packages, notarizes, staples, and validates the DMG.
- Scripts/build_app.sh now applies --options runtime --timestamp automatically when a Developer ID Application identity is selected; local self-signed development builds are unchanged.
- Scripts/publish_release.sh resolves stapler through the new sayflow_find_xcode_tool helper, so stable-release gates keep working when xcode-select points to Command Line Tools.
- The release version comes from the VERSION file (now 1.3.5) and test gates pin both the release version and the notarization requirements.

中文：

- SayFlow 从自签名预发布升级为正式 Developer ID 分发：App 使用 Developer ID Application: ZHIPENG HUANG (UTZUZ8U2J2) 证书签名，启用 Hardened Runtime（flags=0x10000(runtime)）并附带 Apple secure timestamp。
- 新增 Scripts/notarize_release.sh：构建签名 App，校验 Developer ID 授权链、secure timestamp 与 runtime 标志，用 notarytool 公证并 staple，强制 Gatekeeper 输出 source=Notarized Developer ID，随后打包、公证、staple 并验证 DMG。
- Scripts/build_app.sh 在选择 Developer ID Application 身份时自动附加 --options runtime --timestamp；本地自签名开发构建保持原状。
- Scripts/publish_release.sh 通过新的 sayflow_find_xcode_tool 解析 stapler，在 xcode-select 指向 Command Line Tools 的机器上正式发布门禁依然可用。
- 发布版本统一由 VERSION 文件管理（现为 1.3.5），测试门禁同步锁定发布版本与公证要求。

## 2026-08-15

### Release v1.3.4

English:

- Fixed Accept replacement in X/Chrome and other browser editors by no longer trusting an apparent `AXSelectedText` write success for browser content.
- Browser Accept now uses a session-scoped sequence: copy the corrected text, close the panel, reactivate the captured target, verify the current session, target process, frontmost app, original selection, and clipboard, then post `Command+V` directly to the captured PID with `CGEvent.postToPid`. If a required original-selection check cannot be confirmed, the corrected text remains on the clipboard and SayFlow does not paste automatically.
- Accept cancels the active streaming request, and request-attempt guards discard late snapshot, error, and completion callbacks so a closed panel cannot be updated by stale work.
- When direct `AXSelectedText` is missing or blank, selected-text capture now falls back to the WebKit text-marker range.
- Expanded regression coverage for browser transport selection, copy-close-paste ordering, session/focus/selection/clipboard guards, and empty direct AX selection fallback; all `161/161` SayFlowCore tests pass.
- Verified the real X reply editor in Chrome end to end: Accept changed the DOM from `比如想着` to the English correction, the original draft was then restored, and no post was submitted.
- Prepared the repository for public distribution by removing internal-only project material and tightening the public project instructions.
- Redesigned the bilingual project homepage with a dedicated English README and product screenshots.
- Protected local configuration by ignoring common secret and credential files and enforcing owner-only permissions on settings and prompt files.
- Built and verified the stable local-signed universal package `dist/SayFlow-1.3.4.dmg`; `Scripts/verify_package.sh` passed and SHA-256 is `4e6370e21652360df4f5a98612dd0952a1a2f74e33a43beb28a36419e454e045`.

中文：

- 修复 X/Chrome 及其他浏览器编辑器中的 Accept 替换：浏览器内容不再把看似成功的 `AXSelectedText` 写入当作可信结果。
- 浏览器 Accept 现在采用会话级流程：复制 corrected text、关闭面板、重新激活捕获时的目标，再校验当前会话、目标进程、前台 App、原选区和剪贴板，最后通过 `CGEvent.postToPid` 向捕获到的 PID 定向发送 `Command+V`。如果无法重新确认必须校验的原选区，只保留剪贴板中的 corrected text，不自动粘贴。
- 点击 Accept 会取消当前 streaming 请求，并用 request-attempt 标识丢弃迟到的 snapshot、error 和 completion 回调，避免旧任务更新已关闭的面板。
- 当直接读取的 `AXSelectedText` 缺失或为空时，选中文本捕获现在会回退到 WebKit text-marker range。
- 扩充浏览器传输策略、复制—关闭—粘贴顺序、会话/焦点/选区/剪贴板保护及空 AX 直选区回退的回归测试；SayFlowCore `161/161` 全部通过。
- 已在 Chrome 的真实 X 回复编辑器完成端到端验证：Accept 将 DOM 从“比如想着”替换为英文 corrected text，随后恢复原草稿，全程未发帖。
- 清理仅供内部使用的项目资料并收紧公开项目指引，为仓库公开发布做好准备。
- 重设计中英双语项目主页，新增独立英文 README 和产品截图。
- 加强本地配置隐私：忽略常见密钥与凭据文件，并将设置和提示词文件权限限制为仅所有者可读写。
- 生成并验证本地稳定自签名的通用架构安装包 `dist/SayFlow-1.3.4.dmg`；`Scripts/verify_package.sh` 全部通过，SHA-256：`4e6370e21652360df4f5a98612dd0952a1a2f74e33a43beb28a36419e454e045`。

## 2026-08-03

### Release v1.3.3

中文：

- 支持 DeepSeek 最新的 `deepseek-v4-flash` 模型，并采用官方 OpenAI 兼容配置。
- 将 DeepSeek 默认 Base URL 更新为 `https://api.deepseek.com`。
- 自动迁移旧默认地址 `https://api.deepseek.com/v1`，同时保留用户自定义代理地址。
- 增加 DeepSeek 默认配置、旧配置迁移和根 URL 端点生成的回归测试。
- 生成并验证 `dist/SayFlow-1.3.3.dmg`，SHA-256：`b12ea49325a3869eef5536775e93ba8f8f26d2246891badce3cb8859741bd1b7`。

## 2026-07-11

### Release v1.3.2

中文：

- 将提供商检测改为非流式、单 token 的 `ping` 请求，不再等待完整批改结果。
- DeepSeek 请求显式关闭默认思考模式，缩短翻译与批改的可见响应等待。
- 打包脚本改用解析后的证书 SHA-1 指纹签名，避免同名证书导致签名歧义。
- 生成并验证 `dist/SayFlow-1.3.2.dmg`，SHA-256：`46d534274149256cf7f06c84c5753c0f879d13df415f9565ee885cf7651518a4`。

## 2026-05-05

Today was one of those long workshop days. Not a day of one heroic rewrite, but a day of small hinges, tightened screws, and a tool becoming more comfortable in the hand.

今天像一整天坐在工坊里打磨一把旧工具。不是那种惊天动地的重写，而是把每个小铰链拧紧，把每颗螺丝校正，让它拿在手里更顺。

### Summary / 摘要

- Advanced SayFlow from `v1.2.3` to `v1.3.1`.
- 将 SayFlow 从 `v1.2.3` 推进到 `v1.3.1`。
- Added translation mode for single English words and short phrases, with IPA display and real speech playback.
- 增加单词与短词组翻译模式，支持音标展示和真实朗读。
- Improved selection hot-zone behavior for mixed Chinese and English text.
- 改进中英混合文本下的选择热区判断。
- Added prompt scene naming and quick scene switching from the menu bar.
- 增加提示词场景命名，并支持菜单栏快速切换场景。
- Added per-provider model history, so custom model names are easier to reuse.
- 增加按服务商隔离的模型历史，方便复用自定义模型名。
- Reworked result-panel insertion, auto-copy, Accept fallback, and auto-close behavior.
- 调整结果面板的插入、自动复制、Accept 兜底与自动关闭行为。
- Added WeChat compatibility fallback for selected text capture.
- 增加微信选中文本捕获的兼容兜底。
- Built and verified a local stable-signed `V1.3.1` DMG.
- 生成并验证本地稳定签名版 `V1.3.1` DMG。

### Release Timeline / 发布时间线

#### `local` - Release v1.3.1 - 21:21

English:

- Added a clipboard shortcut fallback when macOS Accessibility cannot read selected text in WeChat.
- Added a WeChat-only selection hot-zone fallback that probes the clipboard after a real drag selection, avoiding broad clipboard probes in other apps.
- Added regression tests for runtime copy fallback, WeChat hot-zone fallback, drag gating, and non-WeChat safety.
- Bumped the visible version and packaging scripts to `1.3.1`.
- Built `dist/SayFlow-1.3.1.dmg` with stable local signing.
- Verified `138` SayFlowCore tests, debug build, package signing, universal architectures, DMG checksum, and DMG contents.

中文：

- 当 macOS Accessibility 无法读取微信选中文本时，增加剪贴板快捷复制兜底。
- 为微信单独增加选择热区兜底：只有真实拖拽选择后才探测剪贴板，避免影响其他 App。
- 增加运行时复制兜底、微信热区兜底、拖拽门槛、非微信安全边界的回归测试。
- 将可见版本号和打包脚本更新到 `1.3.1`。
- 生成稳定本地签名包 `dist/SayFlow-1.3.1.dmg`。
- 验证 `138` 个 SayFlowCore 测试、调试构建、包签名、通用架构、DMG 校验和挂载内容。

#### `bf193a2` - Release v1.3.0 Beta - 20:09

English:

- Added `CorrectionMode` and translation-mode detection for one English word or an English phrase of up to three words.
- Added a dedicated translation prompt that asks for American IPA, Chinese translation, empty `changes`, and the fixed label `🦄翻译模式🌈`.
- Added a speaker button in translation mode and wired it to `NSSpeechSynthesizer` so pronunciation playback is real, not decorative.
- Made Accept in translation mode close the result panel without replacing source text.
- Allowed short translation candidates such as `cat` and `Accessibility selected-text capture` to show the floating trigger, while keeping unsafe content filters in place.
- Bumped the visible version and packaging scripts to `1.3.0 Beta`.
- Built `dist/SayFlow-1.3.0 Beta.dmg` with stable local signing.
- Verified `133` SayFlowCore tests, debug build, package signing, universal architectures, DMG checksum, and DMG contents.

中文：

- 增加 `CorrectionMode`，当选中单个英文单词或不超过三个英文词的词组时进入翻译模式。
- 增加翻译模式专用提示词，要求返回美式 IPA、中文释义、空 `changes`，并固定显示 `🦄翻译模式🌈`。
- 在翻译模式里增加小喇叭按钮，并接入 `NSSpeechSynthesizer`，朗读是真的，不是摆设。
- 翻译模式下点击 Accept 只关闭结果面板，不替换原文。
- 允许 `cat`、`Accessibility selected-text capture` 这类短翻译候选唤起浮窗，同时保留 URL、密钥、代码等安全过滤。
- 将可见版本号和打包脚本更新到 `1.3.0 Beta`。
- 生成稳定本地签名包 `dist/SayFlow-1.3.0 Beta.dmg`。
- 验证 `133` 个 SayFlowCore 测试、调试构建、包签名、通用架构、DMG 校验和挂载内容。

#### `b7c4457` - Release v1.2.10 - 19:02

English:

- Reworked Accept fallback so successful replacement closes the panel, and failed replacement copies the corrected text before closing after a short delay.
- Added insert fallback policy: if Accessibility replacement fails, SayFlow tries clipboard paste; if that final path fails, it shows the friendly insertion failure message and auto-closes.
- Tightened the user-facing Chinese insertion failure copy to: "无法插入到当前位置，修改后的句子已在剪贴板中。"
- Kept the existing write/copy/insert/Accept surface stable while changing only the requested button behaviors.

中文：

- 调整 Accept 兜底逻辑：替换成功即关闭面板，替换失败则复制修改后文本，并在短暂延迟后关闭。
- 增加插入兜底策略：Accessibility 替换失败时尝试剪贴板粘贴；最终失败时显示友好提示并自动关闭。
- 将插入失败提示收紧为："无法插入到当前位置，修改后的句子已在剪贴板中。"
- 在只改指定按钮行为的前提下，保留写入、复制、插入、Accept 的整体界面稳定。

#### `459a2ff` - Release v1.2.9 - 17:06

English:

- Added automatic clipboard copy for completed corrections.
- Replaced the old copy button behavior with Insert: keep the original selected text and append the corrected sentence after it.
- Added `ResultPresentationPolicy` to keep result-panel behavior small, testable, and explicit.
- Added tests for completed auto-copy and insertion composition.

中文：

- 增加结果完成后自动把 corrected 文本复制到剪贴板。
- 将原复制按钮调整为"插入"：保留原选中文本，并把 corrected 句子追加在后面。
- 增加 `ResultPresentationPolicy`，让结果面板的行为更小、更可测试、更清楚。
- 增加自动复制和插入拼接的测试。

#### `6bd58e6` - Release v1.2.8 - 12:30

English:

- Added per-provider model history.
- Kept recent model names unique, normalized, limited, and deletable.
- Added a model-history popover in provider settings, so custom model names no longer have to live in memory or sticky notes.
- Preserved model history through settings save/load and provider migration.

中文：

- 增加按服务商隔离的模型历史。
- 模型历史会去重、规范化、限制数量，并支持删除误填项。
- 在服务商设置中增加模型历史弹窗，自定义模型名不用再靠脑子或便签记。
- 在设置保存、读取和服务商迁移时保留模型历史。

#### `2fda746` - Release v1.2.7 - 11:47

English:

- Added prompt scene names for the fixed prompt slots.
- Added a menu-bar scene switcher, making prompt switching faster than opening Settings every time.
- Preserved compatibility with old prompt files by defaulting missing scene names to the slot title.
- Added tests for scene-name persistence and menu presentation.

中文：

- 为固定提示词槽位增加场景命名。
- 在菜单栏增加场景切换入口，不必每次都打开设置窗口。
- 对旧提示词文件保持兼容：缺失场景名时使用槽位标题兜底。
- 增加场景名持久化和菜单展示测试。

#### `2ca138d` - Release v1.2.6 - 11:24

English:

- Expanded mixed Chinese/English trigger boundaries beyond sentence-ending punctuation.
- Allowed Chinese comma, colon, semicolon, enumeration comma, and their ASCII counterparts to serve as a boundary before an English phrase.
- Added regression coverage for inline Chinese context followed by an English phrase.

中文：

- 扩展中英混合文本的触发边界，不再只依赖句号、问号、感叹号。
- 支持中文逗号、冒号、分号、顿号及对应英文标点作为中文上下文与英文片段之间的边界。
- 增加中文上下文后接英文短语的回归测试。

#### `5abde1c` - Release v1.2.5 - 10:51

English:

- Fixed inline Chinese intro plus English sentence detection.
- Split the selection hot-zone logic into clearer helpers for newline-separated and inline mixed-language cases.
- Added tests so a Chinese introduction immediately followed by English still shows the floating trigger.

中文：

- 修复中文引导语后面紧跟英文句子时热区不出现的问题。
- 将选择热区逻辑拆成更清楚的辅助函数，分别处理换行分隔和行内中英混合。
- 增加测试，锁住"中文说明后直接接英文"也应出现浮窗的行为。

#### `fa35a7d` - Release v1.2.4 - 09:09

English:

- Published the `v1.2.4` local-signed baseline.
- Synchronized scripts, visible About version text, acceptance checklist, and completion audit for the release.

中文：

- 发布 `v1.2.4` 本地签名基线版本。
- 同步脚本、About 可见版本、验收清单和完成审计文档。

#### `d5f04e5` - Release v1.2.3 - 08:08

English:

- Made Obsidian writing prepend new entries after the top heading instead of simply appending to the end.
- Added support for newline-separated Chinese introduction followed by English correction candidates in the selection hot zone.
- Added tests for Obsidian prepend behavior and mixed Chinese/English hot-zone visibility.

中文：

- 调整 Obsidian 写入逻辑：新条目会插入到顶部标题之后，而不是简单追加到文件末尾。
- 让选择热区支持"中文说明段落 + 英文待改句子"这种换行分隔的中英混合内容。
- 增加 Obsidian 前置写入和中英混合热区显示的测试。

### Verification Notes / 验证记录

English:

- Latest verified package: `dist/SayFlow-1.3.1.dmg`
- SHA-256: `f9302be463350519ce139190b1f74bb4f9f3a2260bb252876da3802c290a1b49`
- Signing authority: `SayFlow Local Development`
- Architectures: `x86_64 arm64`
- Automated gate: `Scripts/test.sh`
- Package gate: `Scripts/verify_package.sh`

中文：

- 最新已验证包：`dist/SayFlow-1.3.1.dmg`
- SHA-256：`f9302be463350519ce139190b1f74bb4f9f3a2260bb252876da3802c290a1b49`
- 签名身份：`SayFlow Local Development`
- 架构：`x86_64 arm64`
- 自动化门禁：`Scripts/test.sh`
- 安装包门禁：`Scripts/verify_package.sh`

### Old Programmer's Note / 老程序员手记

English:

There is a quiet kind of progress that does not announce itself with a new architecture diagram. A panel closes at the right time. A short word finally brings up the tool. A button stops pretending to copy and starts inserting exactly what the user meant. A tiny speaker becomes honest and speaks.

That is the kind of work this day was made of. The codebase is still the same small macOS app, but it now listens a little better.

中文：

有一种进展，不靠新架构图来证明自己。面板在该关闭的时候关闭；一个短单词终于能唤起工具；一个按钮不再假装复制，而是按用户真正想要的方式插入；一个小喇叭不只是图标，它真的会说话。

今天做的就是这种活。代码库仍然是那个小小的 macOS 应用，但它比早上更会听人话了一点。
