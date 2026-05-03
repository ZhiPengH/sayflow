# 言顺 SayFlow · 图标交付包

---

## 关于 dark 模式（看完这一段你就懂了）

很多人第一反应是"应该出两套图：light 一套、dark 一套"。**macOS 上不是这样的**。

| 用在哪 | 是否要出 dark 版 | 为什么 |
|---|---|---|
| App 图标（Dock / Finder / Launchpad） | **不要** | macOS 不区分 light/dark app 图标。Apple 自家的 Mail、Safari、Notes 在浅色和深色模式下图标都是同一张。 |
| 菜单栏图标（顶栏状态图标） | **不要**（但要打个标志位） | macOS 提供 **Template Image** 机制：你交一张纯黑透明底的图，系统会自动在浅色菜单栏显示黑色、在深色菜单栏显示白色。 |

**结论：** 我交付的 `MenuBarIcon.pdf` 已经是纯黑透明底，只要在 Xcode 里把它的 "Render As" 设成 **Template Image**（或代码里 `image.isTemplate = true`），dark 模式自动就好了。**不需要也不应该出两套 PNG**。

---

## 文件清单

```
sayflow-final/
├── README.md                     # 你正在看的文件
├── sources/                      # SVG 源文件（编辑用）
│   ├── sayflow-app-icon.svg      # 主图 1024
│   ├── sayflow-app-icon-small.svg# 16/32 切片用的简化版
│   └── sayflow-menubar.svg       # 菜单栏模板（纯黑透明底）
├── AppIcon.iconset/              # 10 个 PNG 切片，可直接打成 .icns
│   ├── icon_16x16.png
│   ├── icon_16x16@2x.png
│   ├── icon_32x32.png
│   ├── icon_32x32@2x.png
│   ├── icon_128x128.png
│   ├── icon_128x128@2x.png
│   ├── icon_256x256.png
│   ├── icon_256x256@2x.png
│   ├── icon_512x512.png
│   └── icon_512x512@2x.png
├── MenuBarIcon.pdf               # 菜单栏图标（矢量，推荐）
├── MenuBarIcon@2x.png            # 菜单栏图标 44px（备用）
└── MenuBarIcon@3x.png            # 菜单栏图标 66px（备用）
```

---

## 给 Codex 的 prompt（直接复制粘贴）

把整个 `sayflow-final/` 文件夹放到 Codex 能看到的位置（一般是项目根目录），然后把下面这段话发给它：

```
我把 SayFlow 这个 macOS 菜单栏 App 的新图标资源放在了 sayflow-final/ 文件夹里。
请帮我把项目里现有的旧图标全部替换成新的，按以下步骤来：

1. 替换 App 图标
   - 找到项目里现有的 App 图标配置。可能在：
     * Assets.xcassets 里的 AppIcon entry，或
     * 项目根目录的 .icns 文件，或
     * Info.plist 里的 CFBundleIconFile
   - 把 sayflow-final/AppIcon.iconset/ 里的 10 个 PNG 文件替换进 Assets.xcassets 的 AppIcon entry。
     如果项目用的是 .icns 文件，请在 macOS 上跑：
     iconutil -c icns sayflow-final/AppIcon.iconset -o SayFlow.icns
     然后用生成的 SayFlow.icns 替换旧的。

2. 替换菜单栏图标
   - 找到项目里现有的菜单栏图标（NSStatusBar.system.statusItem 或 SwiftUI 的 MenuBarExtra）。
   - 把 sayflow-final/MenuBarIcon.pdf 拖到 Assets.xcassets 里，命名为 "MenuBarIcon"。
   - 在 Asset 的 Inspector 面板里，把 "Render As" 设成 "Template Image"。
   - 代码里确认菜单栏图标用的是这个 asset 名字，并且：
     * 如果是 AppKit (NSStatusItem)：button.image?.isTemplate = true
     * 如果是 SwiftUI MenuBarExtra(image:)：asset 的 Render As 设成 Template Image 即可
   - 删掉项目里所有手动判断 light/dark 模式来切图的代码——macOS 会自动反色，那些代码现在是冗余的。

3. 跑一下 build，告诉我你改了哪些文件、改了什么代码。
```

---

## 验收标准（替换完之后看这些）

打开你的 App，至少检查这几件事：

1. **Dock / Finder 里的 app 图标** ：是新的米色到苔色渐变 + "言"字波浪化的图标。
2. **菜单栏顶部** ：能看到一个小图标（点 + 三道波浪线）。
3. **切换系统外观（System Settings → Appearance）** ：
   - Light → 菜单栏图标是**黑色**
   - Dark → 菜单栏图标是**白色**
   - **如果反过来或者颜色不变，说明 Template Image 没设对**——回去检查 Asset Inspector 里的 "Render As" 是不是 Template Image。
4. 在 Launchpad 里搜 SayFlow，App 图标显示正确。

---

## 万一你想自己手动操作（不用 Codex）

### 打 .icns

在 macOS 终端里：
```bash
cd 你的项目根目录
iconutil -c icns sayflow-final/AppIcon.iconset -o SayFlow.icns
```
生成的 `SayFlow.icns` 拖到 Xcode 项目里，或替换原有的 .icns。

### 接菜单栏图标

把 `sayflow-final/MenuBarIcon.pdf` 拖到 Xcode 的 `Assets.xcassets` 面板里。然后在右侧 Inspector：
- **Render As**: 选 `Template Image`

代码里：

**SwiftUI（MenuBarExtra）**：
```swift
@main
struct SayFlowApp: App {
    var body: some Scene {
        MenuBarExtra("SayFlow", image: "MenuBarIcon") {
            // 你的菜单内容
        }
    }
}
```

**AppKit（NSStatusItem）**：
```swift
let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
if let button = item.button {
    button.image = NSImage(named: "MenuBarIcon")
    button.image?.isTemplate = true   // 这一行是 dark 模式自动反色的关键
}
```

---

## 如果出问题了

| 现象 | 原因 | 怎么修 |
|---|---|---|
| 菜单栏图标显示成方块或不显示 | 路径或 asset 名字不对 | 检查 `NSImage(named: "MenuBarIcon")` 里的字符串和 Assets.xcassets 里的命名是否完全一致 |
| Dark 模式下菜单栏图标看不见（黑底黑图） | Template Image 没设 | Asset Inspector 里把 "Render As" 改成 Template Image，或代码里加 `isTemplate = true` |
| App 图标在 Dock 里显示模糊 | 切片没装全 | 确认 AppIcon entry 里 16/32/64/128/256/512/1024 全部 10 个尺寸都填了 |
| App 图标在 16/32px 显示糊成一坨 | 切片用了主图而不是 small 版 | 16x16 和 16x16@2x 和 32x32 这三个尺寸要用 `sayflow-app-icon-small.svg` 渲染的 PNG（我已经在 iconset 里区分好了，正常用就行）|

实在不行，把错误截图发给我。
