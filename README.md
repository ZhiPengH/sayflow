<p align="center">
  <img src="./assets/sayflow-app-icon.svg" width="112" alt="言顺 SayFlow 图标">
</p>

<h1 align="center">言顺 SayFlow</h1>

<p align="center">
  <strong>不替你说话，只帮你把话说顺。</strong>
</p>

<p align="center">
  一款驻留菜单栏的原生 macOS 英语表达助手。选中文本，按下快捷键，<br>
  把中英混杂、语法不稳或不够自然的句子，变成可以放心发出去的英文。
</p>

<p align="center">
  <strong>简体中文</strong> · <a href="./README.en.md">English</a>
</p>

<p align="center">
  <a href="#系统要求"><img src="https://img.shields.io/badge/macOS-13%2B-111111?logo=apple&logoColor=white" alt="macOS 13+"></a>
  <a href="./Package.swift"><img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift 5"></a>
  <a href="https://github.com/ZhiPengH/sayflow/tags"><img src="https://img.shields.io/github/v/tag/ZhiPengH/sayflow?sort=semver&label=version&color=6f8c67" alt="最新版本标签"></a>
  <img src="https://img.shields.io/badge/OpenAI-compatible-7b68b5" alt="兼容 OpenAI API">
</p>

<p align="center">
  <img src="./assets/readme/correction-result.jpg" width="100%" alt="言顺将中英混杂、语法不稳的句子改成自然英文，并显示中文释义和学习贴士">
</p>

你大概知道自己想说什么，也能写出一些英文，但真正要发给 AI、同事或客户时，总觉得那句话有点别扭：语法不够稳、词不太达意、语气有点生硬，有时还夹着中文。

言顺不会把你拉进另一个编辑器。它留在菜单栏里，只在你需要时出现：

> **修改前**
>
> I want ask AI 一个 question, but my English not very good, can you help me make this sentence 更自然一点?
>
> **言顺之后**
>
> I want to ask the AI a question, but my English is not very good. Could you help me make this sentence sound more natural?

意思没有变，表达顺了很多。更重要的是，言顺会解释 `want ask → want to ask`、补上缺失的 `is`，并告诉你为什么 `sound more natural` 更符合英语习惯。

## “说中学”：把每次修改变成一次练习

言顺的核心不是替你写一段“高级英文”，而是围绕你原本想表达的意思，完成一个很短的学习闭环：

1. 在当前 App 里选中英文或中英混杂文本。
2. 按下默认快捷键 `⌃⌘S`，或点击选区旁的热区按钮。
3. 查看自然表达、改动解释、中文释义与 `Good to know` 学习贴士。
4. 复制、插入或 `Accept` 替换原文；有价值的内容可以写入 Obsidian。

<p align="center">
  <img src="./assets/readme/workflow-zh.jpg" width="100%" alt="言顺从混乱表达、优化解释、保存到 Obsidian 到替换发送的完整流程">
</p>

## 核心功能

### 1. 选中文本，快捷修正

在 AI 对话框、邮件、文档、Obsidian、Notion、Slack、浏览器输入框等可选中文本的位置，直接唤起言顺。它优先通过 macOS Accessibility 读取选区，并提供剪贴板兜底。

### 2. 不只改句子，也解释为什么

结果弹窗同时展示：

- 更自然、准确的完整英文；
- 原片段与新片段的改动对照；
- 中文解释与整句释义；
- 一条适合当下语境的学习贴士。

你可以维护五组 Prompt 场景，在口语老师、程序员英语老师或自己的教学风格之间快速切换。单个英文单词和短词组会进入翻译模式，并支持发音播放。

<details>
<summary><strong>查看五组 Prompt 场景设置</strong></summary>

<p align="center">
  <img src="./assets/readme/prompt-presets.jpg" width="100%" alt="言顺的五组可编辑 Prompt 场景设置">
</p>

</details>

### 3. 一键替换，留在原来的工作流

确认结果合适后，点击 `Accept` 即可替换选中的原文；也可以复制结果，或把修改后的句子插入当前位置。无需来回切换窗口，也不用手动复制粘贴整段内容。

### 4. 写入 Obsidian，建立自己的英语错题本

把值得复盘的句子、改动原因、中文释义和学习贴士写入指定 Markdown 文件。长期积累后，你得到的不是一堆零散答案，而是一套来自自己真实表达的学习语料。

<details>
<summary><strong>查看 Obsidian 学习记录示例</strong></summary>

<p align="center">
  <img src="./assets/readme/obsidian-learning-log.jpg" width="100%" alt="言顺写入 Obsidian 的英语学习记录，包含修改对照、解释和学习贴士">
</p>

</details>

## 它适合什么，也不是什么

言顺适合高频、轻量、但容易打断思路的英语表达场景：和 AI 对话、写邮件、发消息、记录笔记，或在任何 App 里临时确认一句话是否自然。

它不是完整的英语学习平台，也不是替你改写所有内容的通用写作机器人。它尽量保留你的意思和声音，只处理表达发出前最关键的问题：这句话是否自然、准确，可以放心发送？

## 开始使用

### 系统要求

- macOS 13.0 或更高版本；
- Swift 6.x Command Line Tools（源码使用 Swift 5 语言模式）；
- Accessibility（辅助功能）权限，用于读取选中文本和替换原文；
- 一个可用的 OpenAI 或 OpenAI-compatible 模型服务。

### 从源码构建

当前公开仓库提供源码构建流程。克隆后可先生成本机架构的 App：

```bash
git clone https://github.com/ZhiPengH/sayflow.git
cd sayflow
CODESIGN_IDENTITY=- UNIVERSAL=0 Scripts/build_app.sh
open dist/SayFlow.app
```

首次启动后：

1. 在系统设置中授予言顺 Accessibility 权限；
2. 打开言顺设置，选择模型提供商并填写 API Key；
3. 在任意 App 中选中文本，按 `⌃⌘S` 开始使用。

如果你会反复本地构建，可以运行 `Scripts/ensure_codesign_identity.sh` 创建稳定的本地开发签名，减少重建后重新授权的情况。完整人工验收步骤见 [`docs/acceptance-checklist.md`](./docs/acceptance-checklist.md)。

## 模型服务与接口兼容

内置支持 OpenAI、DeepSeek、小米 MiMo、Kimi、MiniMax、豆包、NVIDIA、Z.ai（中国区），也可以接入任意兼容 OpenAI 协议的自定义服务。

自定义服务支持填写：

- Base URL，例如 `https://api.example.com/v1`；
- 完整 `/chat/completions` endpoint；
- 完整 `/responses` endpoint。

言顺会自动完成 endpoint 规范化，并支持流式 SSE 与结构化 JSON 结果。

## 隐私与本地数据

- 触发批改或翻译时，选中的文本会发送给当前配置的模型服务；连接测试只发送最小 `ping` 请求；
- API Key 保存在 `~/Library/Application Support/SayFlow/provider.env`，不会写入 JSON 设置文件；
- 设置保存在 `~/Library/Application Support/SayFlow/settings.json`；
- Prompt 场景保存在 `~/Library/Application Support/SayFlow/prompts.json`；
- Obsidian 内容只写入你在设置中选择的 Markdown 文件。

请同时阅读并确认你所使用模型服务商的数据处理政策。

## 开发与验证

运行完整本地验证：

```bash
Scripts/test.sh
```

构建 Debug 可执行文件：

```bash
swift build
```

构建并验证 Universal DMG：

```bash
Scripts/package_dmg.sh
Scripts/verify_package.sh
```

当前验证基线覆盖 162 个 `SayFlowCore` 测试，并检查 App 签名、`arm64` / `x86_64` 架构、DMG 校验和与安装包内容。更多状态见 [`docs/completion-audit.md`](./docs/completion-audit.md) 与 [`CHANGLOG.md`](./CHANGLOG.md)。

### 发布官方正式版（Developer ID + 公证）

一次性准备，在这台 Mac 的终端里亲自执行，不要把密码粘贴给任何聊天工具：

1. 在 <https://appleid.apple.com> 创建 App 专用密码（登录和安全 > App 专用密码）。
2. 存入 notarytool 钥匙串凭证，把 YOUR_APPLE_ID 换成你的 Apple ID：

        /Applications/Xcode.app/Contents/Developer/usr/bin/notarytool store-credentials sayflow-notary --apple-id YOUR_APPLE_ID --team-id UTZUZ8U2J2

之后一条命令完成 Developer ID 签名（Hardened Runtime + secure timestamp）、公证、staple 与 Gatekeeper 验证：

    Scripts/notarize_release.sh

脚本要求 spctl 输出 source=Notarized Developer ID，且 App 与 DMG 都通过 stapler validate，否则会中止。通过后再运行 Scripts/publish_release.sh 发布稳定版 GitHub Release。

<details>
<summary><strong>调试第三方 Responses API</strong></summary>

在 Custom provider 中填写完整的 `/v1/responses` endpoint、模型名称和 API Key。言顺会自动识别 Responses API，并发送带有 `stream: true` 和 `text.format.type = json_object` 的请求。

也可以在不向项目文件写入密钥的情况下配置本地调试服务：

```bash
SAYFLOW_DEBUG_ENDPOINT="https://example.com/v1/responses" \
SAYFLOW_DEBUG_MODEL="model-name" \
SAYFLOW_DEBUG_API_KEY="sk-..." \
Scripts/configure_debug_provider.sh
```

脚本会更新本地设置，并把密钥写入 `provider.env`。

</details>

---

<p align="center">
  <strong>言顺</strong>，取的是“把话说顺”的意思。<br>
  不炫技，不替你说话，只让沟通少一点阻力。
</p>
