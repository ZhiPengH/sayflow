# Graker（复刻版）产品需求文档 v0.3

> **文档状态**：v0.3（基于截图反馈做了重大收敛——砍掉翻译/解释模式、移除 Origin 区块；详见第 9 节决策记录）
> **作者背景**：基于公开仓库 README + Release Notes v1.0.7/v1.0.8 + 用户提供的真机截图 + 用户口述还原；上游源码私有，未阅读。
> **目标读者**：你自己 + 后续接手开发的人（包括 Claude Code）。
> **范围**：在 macOS 上复刻 Graker 的核心功能（语法批改），并新增两项个人功能（Obsidian 写入 + 弹窗跟随鼠标）。

---

## 1. 产品定位

一句话：**一款常驻 macOS 菜单栏的纯语法批改工具，划词即出"修改后的英文 + 改动详情 + 中文释义 + 学习贴士"，专为中国英语学习者打造。**

复刻版与同类工具（Bob、Pot、沙拉查词）的差异：

1. **极度专一**：不做翻译模式、不做单词解释模式、不做 OCR——只做"修语法"这一件事，所有界面元素都为这一件事服务
2. **本地化深度集成**：原生支持 OpenAI 兼容协议（DeepSeek、Kimi、MiniMax、豆包、小米 MiMo 等 6+ 家），并新增"一键写入个人 Obsidian 笔记"的工作流闭环
3. **教学型输出**：不只给修改结果，还给改动列表（带解释）+ 中文 gloss + Good to know 学习贴士

复刻版在原版基础上叠加两项新功能（详见第 5 节）：写入 Obsidian、弹窗跟随鼠标。

---

## 2. 目标用户

| 维度 | 描述 |
|---|---|
| 主要用户 | 中国地区英语学习者 / 知识工作者 |
| 使用场景 | 阅读英文文献、写英文邮件/推文、写英文 LinkedIn 时即时检查语法和地道表达 |
| 技术门槛 | 能配置 API Key 即可，不需要懂代码 |
| 操作系统 | macOS 13.0 (Ventura) 及以上，Apple Silicon + Intel 通用二进制 |

---

## 3. 核心使用流程

```
用户在任意 App 选中英文文本
        ↓
触发 Graker（划词热区 / ⌥+G 快捷键）
        ↓
Graker 通过 macOS Accessibility API 读取选中内容
        ↓
拼装语法批改 Prompt（要求结构化 JSON 输出）
        ↓
调用配置好的 LLM 提供商（流式）
        ↓
弹窗渲染：Corrected（含 diff pill 和 中文 gloss）+ Good to know
        ↓
用户操作：复制 / Accept 替换原文 / 快速写入 Obsidian / 关闭
```

---

## 4. 复刻范围（原版功能）

### 4.1 系统集成

| 项 | 要求 |
|---|---|
| 程序形态 | macOS 菜单栏常驻 App，无 Dock 图标 |
| 启动方式 | 用户从 Applications 启动，可设置开机自启动 |
| 权限 | 首次启动引导用户授予 **Accessibility（辅助功能）** 权限，用于读取选中文本；引导文案需明确说明用途 |
| 安装包 | `.dmg`，universal binary，附 SHA-256 校验值 |
| 系统要求 | macOS 13.0+ |

### 4.2 文本捕获

- **方式一（必须）**：通过 macOS Accessibility API 读取当前活跃 App 中的选中文本
- **方式二（建议）**：剪贴板兜底——当 Accessibility 拿不到文本时，提示用户复制后再触发
- **方式三（必须）**：全局快捷键，默认 `⌥+G`，可在设置里改键

### 4.3 AI 后端

#### 4.3.1 内置提供商（参考 v1.0.7 / v1.0.8 Release Notes）

| 提供商 | 默认模型 | 协议 | 备注 |
|---|---|---|---|
| OpenAI | gpt-4o-mini（默认） | OpenAI 原生 | 海外 |
| DeepSeek | deepseek-v4-flash | OpenAI 兼容 | 国内 |
| 小米 MiMo | mimo-v2.5 | OpenAI 兼容 | 国内，三集群（China / Singapore / Europe）可选 |
| Moonshot Kimi | kimi-latest | OpenAI 兼容 | 国内 |
| MiniMax | abab6.5s-chat | OpenAI 兼容 | 国内 |
| 豆包（火山方舟） | doubao-1-5-pro | OpenAI 兼容 | 国内 |
| **自定义** | 用户填写 | OpenAI 兼容 | 任意支持 `POST /chat/completions` + Bearer Auth 的服务 |

> v1.0.8 的关键能力：自定义 Provider 既接受 base URL（`https://api.example.com/v1`）也接受完整 curl 风格 endpoint（`https://api.example.com/v1/chat/completions`），内部做 normalize。这是个体贴的设计，复刻版必须保留。

#### 4.3.2 提供商配置项

每个提供商需要可配置：
- API Key（密文存储，建议用 macOS Keychain）
- Base URL（除官方默认外可覆盖）
- Model 名称（自由输入，不限定下拉）
- Temperature（默认 0.2，语法批改宜低温度求稳）
- 当前选中状态（同时只有一个 Active Provider）

#### 4.3.3 单一模式：语法批改

**复刻版只做语法批改，不做翻译模式、不做解释模式**——这是 v0.3 收敛的核心决策。原版 Graker 本身就是单一用途的语法批改器，强行加多模式会破坏产品定位。如未来确实需要翻译/解释，应作为独立 App 或 v2.0 大版本规划，不混进 v1.0。

#### 4.3.4 结构化输出契约

复刻版要求 LLM 返回 **JSON 结构化数据**，而非自由文本。原因：

1. 弹窗需要分别渲染"修改后的句子（带 diff pill）"、"改动列表"、"中文 gloss"、"Good to know"四个独立区块
2. "快速写入 Obsidian"需要选择性引用其中几个字段
3. 自由文本解析脆弱，结构化 JSON 一次拿到位

##### 4.3.4.1 输出 Schema

```json
{
  "corrected": "The market is unpredictable in the short term.",
  "changes": [
    {
      "old": "market are",
      "new": "market is",
      "explain": "主语 the market 是单数，be 动词应为 is"
    },
    {
      "old": "in short-term",
      "new": "in the short term",
      "explain": "固定搭配：表示\"短期内\"时，习惯用法是 in the short term，中间需要加定冠词 the。"
    }
  ],
  "translation_zh": "市场在短期内是不可预测的。",
  "good_to_know": "哈哈，其实很多同学都会在名词单复数上栽跟头。下次写句子时，记得先找动词，再看主语是单数还是复数..."
}
```

字段说明：

| 字段 | 必含 | 用途 |
|---|---|---|
| `corrected` | 是 | 修改后的完整英文句子，弹窗主体显示 |
| `changes` | 是（可空数组）| 改动列表，弹窗内用 diff pill 高亮，点击 pill 弹 popover 展示 explain |
| `translation_zh` | 是 | 修改后句子的中文翻译，作为 gloss 显示在 Corrected 下方 |
| `good_to_know` | 否 | 学习贴士，存在则显示 GTK 卡片，不存在则不渲染 |

##### 4.3.4.2 调用方式

请求时附带：

```http
response_format: {"type": "json_object"}
stream: true
```

绝大多数 OpenAI 兼容 Provider（DeepSeek、Kimi、MiniMax、豆包、MiMo）都支持 `json_object` 模式。客户端做**流式 JSON 增量解析**，每收到完整字段就立即渲染对应区块，不等整段返回。

##### 4.3.4.3 Prompt 模板（用户可编辑、可调试）

> **设计原则**：Prompt 不做黑盒，以模板形式暴露给用户编辑。理由：允许微调输出风格、对比不同模型的指令服从度、便于排查"为什么这次输出不对"。

存储位置：`~/Library/Application Support/Graker/prompts.json`，明文 JSON，方便外部备份。

支持占位符：

| 变量 | 含义 |
|---|---|
| `{{text}}` | 用户选中的原始英文（必含） |

##### 4.3.4.4 出厂默认模板

```json
{
  "system": "你是一名面向中国英语学习者的语法批改老师。给定一段英文，你需要：\n1. 修正其中的语法、拼写、固定搭配错误\n2. 给出每处改动的对照（原始片段、改后片段、中文解释）\n3. 提供修改后句子的中文翻译\n4. 给一段口语化、带鼓励的学习贴士（good_to_know）\n\n严格按以下 JSON 格式输出，不要任何额外说明或 markdown 代码块：\n{\n  \"corrected\": \"修改后的完整英文句子\",\n  \"changes\": [{\"old\": \"原片段\", \"new\": \"新片段\", \"explain\": \"中文解释\"}],\n  \"translation_zh\": \"修改后句子的中文\",\n  \"good_to_know\": \"口语化的学习贴士，2-4 句\"\n}",
  "user": "{{text}}"
}
```

##### 4.3.4.5 设置面板的 Prompts 标签

UI 包含：

- system / user 双框，等宽字体
- "测试运行"按钮：用一段示例错句立刻调用当前 Active Provider，结果以最终弹窗形态预览（含 diff pill），按钮旁灰字提示"会消耗一次 API 调用"
- "恢复默认"按钮
- "导出 / 导入"（JSON 文件）

##### 4.3.4.6 容错

- 用户保存模板时若占位符 `{{text}}` 缺失或语法不合法，保存按钮禁用 + 红字提示
- 调用时若 LLM 返回的 JSON 不能解析（缺字段、非法 JSON），弹窗顶部显示黄条 "AI 返回格式异常，可点击重试"，并把原始返回内容收进可展开的"原始响应"区，方便用户调试 prompt

### 4.4 结果弹窗（核心 UI）

#### 4.4.1 形态
- 圆角 12 px、米色暖卡片背景（参考用户提供的原版截图，#F5F1E8 一类的奶油色）
- 始终置顶（floating panel）
- 不抢焦点（用户在原 App 选中后弹窗出现，原 App 仍保留焦点）
- 点击窗外区域或按 `Esc` 关闭

#### 4.4.2 默认尺寸
- 宽 ~ 540 px，最小高 ~ 220 px，按内容自适应增长，最大不超过屏幕高度的 60%

#### 4.4.3 弹窗位置
- **原版行为**：固定弹在屏幕**左下角**
- **复刻版默认行为**：见第 5.2 节——改为**跟随鼠标位置**

#### 4.4.4 弹窗内容结构（自上而下）

```
┌────────────────────────────────────────────────┐
│ 📌 Graker     The market are unpredict...   ×  │  顶部栏：图钉、应用名、原文截短预览、关闭
├────────────────────────────────────────────────┤
│                                                 │
│ Corrected               [写入] [复制] [✓Accept] │  绿色 section 标题 + 三个右对齐按钮
│ The [market is] unpredictable [in the short    │  主句，改动用绿色 pill 高亮
│ term].                                          │
│ │ 市场在短期内是不可预测的。                     │  中文 gloss，左侧细线
│                                                 │
│ ┌────────────────────────────────────────────┐ │
│ │ 💡 Good to know                             │ │  米黄色卡片，棕色标题
│ │ 哈哈，其实很多同学都会在名词单复数上栽跟头… │ │
│ └────────────────────────────────────────────┘ │
│                                                 │
└────────────────────────────────────────────────┘
```

设计要点：

- **不展示 Origin（原始错句）**：让学习者把错的句子和对的句子并排看，会让大脑同时记住两套，反而妨碍纠错。错句信息只通过两个隐含通道传达——顶部栏的截短预览（"这是我刚才选的"）+ 主句中的绿色 diff pill（点击 pill 看 popover 知道改了哪里）
- **diff pill 交互**：点击绿色 pill 弹出小 popover，显示 `Replaced [old] with [new]` + 中文 explain（参考用户提供的截图 2）
- **三个按钮的语义**：
  - 写入（图标按钮）→ 快速写入 Obsidian，hover 显示 tooltip "快速写入 Obsidian"
  - 复制（图标按钮）→ 复制 corrected 字段到剪贴板，hover 显示 tooltip "复制"
  - Accept（图标 + 文字）→ 通过 Accessibility API 把当前 App 的选中文本替换为 corrected 内容
- **顺序约束（从左到右）**：写入 → 复制 → Accept。前两个图标对齐紧凑，Accept 作为主操作带文字标签

#### 4.4.5 流式渲染策略

调用 LLM 时使用 `stream: true` + `response_format: {type: "json_object"}`：

- 客户端做增量 JSON 解析，每收到一个完整字段立即渲染对应区块
- 渲染顺序：`corrected` 先到先显（含 diff pill）→ `translation_zh` → `good_to_know`
- 字段未完整时不渲染（避免半截 pill 出现）

体感性能：触发到第一个字符出现 < 1.5s（受 LLM TTFT 影响），全文完整 < 5s

### 4.5 设置面板

独立窗口，分组：

1. **General**：开机自启动、全局快捷键（默认 `⌥+G`）
2. **Providers**：上述 7 类提供商的 API Key / Base URL / Model 配置，含切换 Active
3. **Prompts**：单一语法批改模板的 system / user 编辑器 + 测试运行（详见 4.3.4）
4. **Display**：弹窗位置策略（见 5.2）、弹窗主题（深/浅/跟随系统）
5. **Obsidian**：目标 Markdown 文件路径（见 5.1）
6. **About**：版本号、Releases 链接、SHA-256 校验说明

### 4.6 更新与校验

- 每次发布在 GitHub Releases 提供 SHA-256
- App 内可选自动检查更新（建议放 General 设置里）

---

## 5. 新增功能（个人需求增量）

### 5.1 快速写入 Obsidian

#### 5.1.1 用户故事

> 我在阅读英文资料时，遇到一个值得收藏的句子或语法点，触发 Graker 看完 AI 解释后，**一键把这条记录追加到我 Obsidian 里指定的 Markdown 文件**，无需切换 App、无需手动粘贴。

#### 5.1.2 UI 位置

按钮位于 Corrected 区块标题行的右侧，紧邻"复制"图标的左侧：

```
Corrected                  [📝 写入] [📋 复制] [✓ Accept]
```

样式约束：

- **图标按钮**（无文字标签）：尺寸与"复制"图标一致（14×14 SVG），两者紧贴排列
- **hover 显示 tooltip**："快速写入 Obsidian"
- **点击反馈**：图标短暂变成绿色 ✓ checkmark，1.6 秒后恢复（与"复制"按钮的反馈一致）
- **不要文字标签**："快速写入"四个字会破坏顶部按钮区的视觉简洁度，且功能学习曲线只有第一次——记住一次后图标就够用

#### 5.1.3 设置项

设置面板 → Obsidian 标签页：

| 字段 | 类型 | 说明 |
|---|---|---|
| 目标 Markdown 文件 | 文件选择器（限 .md，绝对路径） | 例：`/Users/zhipeng/Obsidian/MyVault/02-Inbox/Graker-Inbox.md`。**单文件追加，不需要 Vault 概念**——用户自己挑文件位置即可 |
| 写入模板 | 多行文本框 | 见下方默认模板，用变量占位 |
| 时区 | 下拉 | 默认跟随系统 |

#### 5.1.4 默认写入模板

```markdown

---

**{{timestamp}}**

{{corrected}}

**Changes:**
{{changes_block}}

> {{translation_zh}}

**Good to know**

{{good_to_know}}

```

可用变量：

| 变量 | 含义 | 示例渲染 |
|---|---|---|
| `{{timestamp}}` | ISO 8601，跟随系统时区 | `2026-05-03 14:32` |
| `{{corrected}}` | LLM 返回的修改后英文句子 | `The market is unpredictable in the short term.` |
| `{{changes_block}}` | 改动列表，自动展开为 markdown 列表 | `- \`market are\` → \`market is\` （主语 the market 是单数...）`<br>`- \`in short-term\` → \`in the short term\` （固定搭配...）` |
| `{{translation_zh}}` | 修改后句子的中文翻译 | `市场在短期内是不可预测的。` |
| `{{good_to_know}}` | 学习贴士全文 | `哈哈，其实很多同学都会在名词单复数上栽跟头...` |
| `{{source_app}}` | 来源 App 名称（可选） | `Safari` |

**写入范围说明**：

- **保存**：`corrected`、`changes`（含 explain）、`translation_zh`、`good_to_know`
- **不保存**：用户的原始错句（避免在自己的 Obsidian 笔记里强化错误印象）

如果用户想极简化（只要修改后句子 + GTK，不要 changes 和翻译），把模板里对应变量删掉即可。

#### 5.1.5 写入行为

- **追加模式**：以 `O_APPEND` 方式写入，绝不覆盖
- **文件不存在**：自动创建（含上层目录），并写入一个 H1 标题如 `# Graker Inbox`
- **写入失败**：弹 toast 提示具体原因（路径不存在 / 无权限 / 磁盘满），原始数据不丢失，按钮可重试
- **成功反馈**：图标短暂变成绿色 ✓ checkmark 1.6 秒后恢复，无打扰式系统通知

#### 5.1.6 边界

- 不与 Obsidian App 进程交互、不需要 Obsidian 运行——本质是**写本地 .md 文件**
- 如果 Obsidian 正打开同一文件，依靠 Obsidian 自带的文件监听刷新即可
- 不做云同步、不做条目去重——这是 Inbox 思路

### 5.2 弹窗跟随鼠标位置

#### 5.2.1 用户故事

> 我在屏幕中部或右上方阅读时，弹窗跑到左下角让我视线大幅跳跃。希望弹窗在**当前鼠标附近**出现，看完即关。

#### 5.2.2 行为规范

- 触发 Graker 的瞬间，记录当前鼠标全局坐标 `(x, y)`
- 弹窗默认锚点：弹窗**左上角**置于 `(x + 12, y + 12)`，向右下偏移 12 px 避免遮住光标
- **越界处理**：
  - 如果 `x + 弹窗宽度 > 屏幕右边界`，则锚点改为弹窗**右上角**对齐 `(x - 12, y + 12)`
  - 如果 `y + 弹窗高度 > 屏幕下边界`，则纵向翻转，锚点改为弹窗**左下角**对齐 `(x + 12, y - 12)`
  - 多显示器：使用鼠标当前所在的 NSScreen 作为越界判断依据，不跨屏幕
- **重复触发同一段文本**：弹窗已存在且选中文本与上次完全一致时，**保持原坐标原位刷新内容**，不重新计算鼠标位置——避免视觉跳动

#### 5.2.3 设置项

设置 → Display → 弹窗位置策略，单选：

- ◉ 跟随鼠标（新默认）
- ○ 屏幕左下角（保留兼容原版行为）
- ○ 屏幕中央
- ○ 上次关闭位置

---

## 6. 非功能需求

| 类别 | 要求 |
|---|---|
| 性能 | 触发到弹窗显示 < 200ms（不含 LLM 响应时间）；流式 token 间延迟 < 50ms |
| 隐私 | API Key 写入 macOS Keychain，不进 plist 明文；选中文本不本地缓存（除非用户主动写入 Obsidian） |
| 网络 | 全程 HTTPS；超时默认 30s，可配置 |
| 可用性 | 离线时按钮禁用 + 提示"网络不可用"；API 报错给出 HTTP 状态码 + 原始 message |
| 国际化 | 至少中文 + English，跟随系统语言 |
| 包体 | 期望 < 30MB（参考同类 Bob、Pot） |

---

## 7. 技术建议（非约束）

> 这一节是建议方向，不是硬要求，决策权在最终实现的人。

| 维度 | 建议 |
|---|---|
| 语言 | Swift + SwiftUI（菜单栏 App 的现代选择） |
| 网络 | URLSession 原生，自己实现 SSE 流式解析（OpenAI 兼容协议都用 `data:` 前缀的 SSE） |
| JSON 增量解析 | 用 `JSONStreamingParser` 一类的渐进式解析器，每识别完整字段触发渲染回调；纯文本 json mode 实现可参考 `yajl` Swift 绑定 |
| Keychain | 使用 `kSecClassGenericPassword` |
| 划词 | `AXUIElementCopyAttributeValue` 拿 `kAXSelectedTextAttribute` |
| Accept 替换 | `AXUIElementSetAttributeValue` 写回 `kAXSelectedTextAttribute`，部分非原生 App（如 Electron）可能不支持，需做能力探测 + 降级到剪贴板 |
| 弹窗 | `NSPanel` (`.nonactivatingPanel`)，不抢焦点 |
| Obsidian 写入 | 不需要任何 Obsidian SDK，FileHandle 追加即可；不要锁文件 |
| 鼠标坐标 | `NSEvent.mouseLocation`（注意 macOS 坐标系 Y 轴是从下往上） |

---

## 8. 验收标准

复刻版 v1.0 发布前必须通过：

1. ✅ 在 Safari、Chrome、预览（PDF）、Word、Notes 中划词均能成功捕获文本
2. ✅ 全局快捷键 `⌥+G` 默认开启且可在 General 中改键
3. ✅ 在 Settings 里完成任意一家 OpenAI 兼容服务（含自定义）的配置后能成功调用，且能正确返回 4 字段 JSON
4. ✅ 单一语法批改 prompt 模板可在 Prompts 标签页编辑、保存、恢复默认、测试运行（测试运行结果按真实弹窗形态预览）
5. ✅ 弹窗渲染包含 Corrected（含 diff pill + 中文 gloss）+ Good to know 两个区块，**不渲染 Origin**
6. ✅ 点击绿色 diff pill 弹出 popover，正确显示 `Replaced [old] with [new]` + 中文 explain
7. ✅ Accept 按钮能成功替换原 App 的选中文本（在原生 App 上）
8. ✅ 写入按钮（图标）和复制按钮（图标）紧邻排列，hover 显示 tooltip，点击后图标变绿 ✓ 反馈
9. ✅ 弹窗在多显示器、不同 DPI 下不越界
10. ✅ 写入 Obsidian 后能在文件中看到 corrected、changes 列表、translation_zh、good_to_know 四部分
11. ✅ 目标文件不存在时自动创建，无权限时给出清晰错误
12. ✅ 弹窗位置策略 4 种均可正常切换并表现一致
13. ✅ 同段文本重复触发时弹窗原地刷新，不发生视觉跳动
14. ✅ LLM 返回非法 JSON 时弹窗顶部黄条提示 + 显示原始响应，不直接崩溃
15. ✅ Apple Silicon 和 Intel Mac 均能启动
16. ✅ Accessibility 权限被吊销后给出引导，不直接崩溃

---

## 9. 决策记录

### 9.1 v0.1 → v0.2（基于志鹏 Q1–Q6 的反馈）

| # | 问题 | 决策 |
|---|---|---|
| Q1 | Prompt 模式数量？是否做成黑盒？ | 三种模式：语法、翻译、解释；Prompt 全部以模板形式暴露，可编辑、可调试 |
| Q2 | 触发方式？快捷键默认值？ | 划词 + 全局快捷键并行，默认 `⌥+G` |
| Q3 | 写入 Obsidian 是否按日期分文件？ | 不需要，单一文件追加，用户自选文件位置 |
| Q4 | 是否支持 YAML frontmatter？ | 不需要 |
| Q5 | 是否做历史记录面板？ | v1.0 不做，靠 Obsidian 写入归档 |
| Q6 | 同段文本重复触发是否原地刷新？ | 是，保持坐标原位刷新避免跳动 |

### 9.2 v0.2 → v0.3（基于真机截图反馈做的重大收敛）

志鹏提供了原版 Graker 的真实截图后，发现原版是**单一用途的语法批改器**——根本没有"翻译"和"解释"两种模式，所谓"翻译"只是修改后句子的中文 gloss 自动跟在 Corrected 下面。基于这个发现做了如下收敛：

| # | 决策 | 影响章节 |
|---|---|---|
| D1 | **砍掉翻译、解释模式**，只做语法批改 | §1 / §3 / §4.3.3 / §4.3.4 / §4.5 / §10 |
| D2 | **去掉弹窗里的 Origin 区块**——并排展示错句和正句反而妨碍纠错；错句信息通过顶部栏截短预览 + 主句 diff pill 隐含传达 | §4.4.4 |
| D3 | **LLM 输出契约改为结构化 JSON**（4 字段：corrected / changes / translation_zh / good_to_know）；客户端做流式 JSON 增量解析 | §4.3.4 / §4.4.5 |
| D4 | **diff pill 交互**：点击绿色 pill 弹 popover，显示 `Replaced [old] with [new]` + 中文 explain | §4.4.4 |
| D5 | **三个按钮顺序定为 写入→复制→Accept**；写入和复制为图标按钮（hover 显示 tooltip），不要"快速写入"四字标签 | §4.4.4 / §5.1.2 |
| D6 | **Obsidian 写入内容**：corrected + changes（含 explain）+ translation_zh + good_to_know，**不写 origin** | §5.1.4 |

### 9.3 待志鹏确认的小问题

| # | 问题 | 我的处理 |
|---|---|---|
| R1 | 原版的"Accept"按钮颜色用蓝色（系统强调色），我目前 mockup 也照搬。但 macOS HIG 一般用蓝色表示安全的默认动作，"替换原文"对部分场景（如已发布的微信消息）可能不可逆。是否需要改成中性灰色？ | 默认保持蓝色，与原版一致；如果你日常多在不可撤销的场景用，告诉我换中性色 |
| R2 | LLM JSON 返回偶尔会被模型自作主张包在 \`\`\`json ... \`\`\` 代码块里。客户端是否需要做 markdown 代码块剥离的兜底？ | 默认做剥离（实测 DeepSeek 偶发包代码块），不做交互提示 |
| R3 | 顶部栏的"原文截短预览"超长时怎么截？保留前 N 字 + ... 还是中间省略？ | 默认前 N 字 + `...`（参考原版截图行为），N 按弹窗宽度自适应 |

---

## 10. 不在范围内（明确排除）

为了避免范围蔓延，**这些功能 v1.0 不做**：

- ❌ **翻译模式**（v0.2 曾计划，v0.3 砍掉，专注语法批改）
- ❌ **解释模式**（同上）
- ❌ OCR / 截图翻译（Pot 强项，不抄）
- ❌ 离线词典（沙拉查词强项，不抄）
- ❌ 语音播放（不做 TTS）
- ❌ 浏览器扩展同步
- ❌ Windows / Linux 版本
- ❌ 与 Notion、Logseq、Roam 的集成（聚焦 Obsidian 一家就好）
- ❌ 多账号 / 团队协作
- ❌ 历史记录面板（写入 Obsidian 即视为外部归档）

---

*文档版本：v0.3 · 最后更新：2026-05-03*
