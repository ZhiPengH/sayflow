import Foundation

public enum AppLanguage: String, Equatable {
    case english
    case chinese

    public static func preferred(from preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard let first = preferredLanguages.first?.lowercased() else {
            return .english
        }
        return first.hasPrefix("zh") ? .chinese : .english
    }
}

public enum L10nKey: String, CaseIterable {
    case appName
    case appOffline
    case checkGrammar
    case settingsMenu
    case quitMenu
    case settingsTitle
    case tabGeneral
    case tabProviders
    case tabPrompts
    case tabDisplay
    case tabObsidian
    case tabAbout
    case launchAtLogin
    case autoCheckUpdates
    case saveHotkey
    case saveTimeout
    case globalShortcut
    case networkTimeout
    case activeProvider
    case apiKey
    case baseURLEndpoint
    case model
    case temperature
    case saveProvider
    case testProvider
    case providerTestInProgress
    case providerTestSucceededFormat
    case providerTestFailedFormat
    case save
    case testRun
    case restoreDefault
    case export
    case `import`
    case consumesOneAPICall
    case systemPrompt
    case userPrompt
    case popupPosition
    case theme
    case chooseMarkdown
    case saveFileMenu
    case noRecentMarkdownFiles
    case targetMarkdownFile
    case timeZone
    case writeTemplate
    case saveObsidianSettings
    case invalidObsidianPathTitle
    case invalidObsidianPathEmpty
    case invalidObsidianPathRelative
    case invalidObsidianPathNotMarkdown
    case aboutName
    case aboutVersion
    case aboutReleases
    case aboutShaNote
    case systemTimeZone
    case corrected
    case retry
    case rawResponse
    case checkingGrammar
    case writeFallback
    case writeTooltip
    case copyFallback
    case copyTooltip
    case accept
    case acceptCopiedFallback
    case goodToKnow
    case replacedChangeFormat
    case networkUnavailableTitle
    case networkUnavailableMessage
    case accessibilityTitle
    case accessibilityMessage
    case accessibilityOnboardingTitle
    case accessibilityOnboardingMessage
    case openSystemSettings
    case notNow
    case noSelectedTextTitle
    case noSelectedTextMessage
    case noActiveProvider
    case missingAPIKey
    case chooseObsidianFirst
    case writeFailedPrefix
    case obsidianWriteNoPermission
    case obsidianWriteDiskFull
    case obsidianWritePathUnavailable
    case streamParseFailedPrefix
    case networkRequestFailedPrefix
    case apiRequestFailedPrefix
    case malformedAIJSONRetry
    case failedSaveSettings
    case failedSaveAPIKey
    case invalidProviderTitle
    case invalidProviderBaseURL
    case invalidProviderModel
    case invalidHotkeyTitle
    case invalidHotkeyMessage
    case hotkeyRegistrationFailedTitle
    case hotkeyRegistrationFailedMessageFormat
    case exportFailed
    case importFailed
    case launchAtLoginFailed
    case updateAvailableTitle
    case updateAvailableMessageFormat
    case openReleasePage
    case followMouse
    case bottomLeft
    case center
    case lastClosed
    case themeSystem
    case themeLight
    case themeDark
}

public enum L10n {
    public static func tr(_ key: L10nKey, language: AppLanguage = .preferred()) -> String {
        translations[language]?[key] ?? translations[.english]?[key] ?? key.rawValue
    }

    private static let translations: [AppLanguage: [L10nKey: String]] = [
        .english: [
            .appName: "SayFlow",
            .appOffline: "SayFlow Offline",
            .checkGrammar: "Check Grammar",
            .settingsMenu: "Settings...",
            .quitMenu: "Quit SayFlow",
            .settingsTitle: "SayFlow Settings",
            .tabGeneral: "General",
            .tabProviders: "Providers",
            .tabPrompts: "Prompts",
            .tabDisplay: "Display",
            .tabObsidian: "Obsidian",
            .tabAbout: "About",
            .launchAtLogin: "Launch at login",
            .autoCheckUpdates: "Check for updates automatically",
            .saveHotkey: "Save hotkey",
            .saveTimeout: "Save timeout",
            .globalShortcut: "Global shortcut",
            .networkTimeout: "Network timeout",
            .activeProvider: "Active provider",
            .apiKey: "API Key",
            .baseURLEndpoint: "Base URL / Endpoint",
            .model: "Model",
            .temperature: "Temperature",
            .saveProvider: "Save Provider",
            .testProvider: "Test",
            .providerTestInProgress: "Testing provider...",
            .providerTestSucceededFormat: "Provider test passed: %@ endpoint, HTTP %d.",
            .providerTestFailedFormat: "Provider test failed: %@",
            .save: "Save",
            .testRun: "Test Run",
            .restoreDefault: "Restore Default",
            .export: "Export",
            .import: "Import",
            .consumesOneAPICall: "Consumes one API call.",
            .systemPrompt: "System",
            .userPrompt: "User",
            .popupPosition: "Popup position",
            .theme: "Theme",
            .chooseMarkdown: "Open",
            .saveFileMenu: "Save File",
            .noRecentMarkdownFiles: "No recent Markdown files",
            .targetMarkdownFile: "Target Markdown file",
            .timeZone: "Time zone",
            .writeTemplate: "Write template",
            .saveObsidianSettings: "Save Obsidian Settings",
            .invalidObsidianPathTitle: "Invalid Obsidian path",
            .invalidObsidianPathEmpty: "Choose an absolute .md file path.",
            .invalidObsidianPathRelative: "Use an absolute Markdown file path.",
            .invalidObsidianPathNotMarkdown: "The Obsidian target must be a .md file.",
            .aboutName: "SayFlow",
            .aboutVersion: "Version 1.2.2",
            .aboutReleases: "Releases: https://github.com/ZhiPengH/sayflow-release/releases",
            .aboutShaNote: "Each DMG build script prints SHA-256 for verification.",
            .systemTimeZone: "System",
            .corrected: "Corrected",
            .retry: "Retry",
            .rawResponse: "Raw response",
            .checkingGrammar: "Checking grammar...",
            .writeFallback: "Write",
            .writeTooltip: "Write to Obsidian",
            .copyFallback: "Copy",
            .copyTooltip: "Copy",
            .accept: "Accept",
            .acceptCopiedFallback: "Could not replace the original selection. The corrected text was copied to the clipboard.",
            .goodToKnow: "Good to know",
            .replacedChangeFormat: "Replaced [%@] with [%@]",
            .networkUnavailableTitle: "Network unavailable",
            .networkUnavailableMessage: "Connect to the network and trigger SayFlow again.",
            .accessibilityTitle: "Accessibility permission required",
            .accessibilityMessage: "SayFlow needs Accessibility permission to read and replace selected text.",
            .accessibilityOnboardingTitle: "Allow Accessibility for SayFlow",
            .accessibilityOnboardingMessage: "SayFlow uses Accessibility only to read the text you selected and replace it when you click Accept.",
            .openSystemSettings: "Open System Settings",
            .notNow: "Not Now",
            .noSelectedTextTitle: "No selected text",
            .noSelectedTextMessage: "Select English text first, or copy it and trigger SayFlow again.",
            .noActiveProvider: "No active provider configured.",
            .missingAPIKey: "Missing API key. Open Settings -> Providers.",
            .chooseObsidianFirst: "Choose a target Markdown file in Settings -> Obsidian first.",
            .writeFailedPrefix: "Failed to write to Obsidian: ",
            .obsidianWriteNoPermission: "No permission to write the target Markdown file.",
            .obsidianWriteDiskFull: "Disk is full; SayFlow could not write to the target Markdown file.",
            .obsidianWritePathUnavailable: "Target path is unavailable or invalid.",
            .streamParseFailedPrefix: "Failed to parse AI stream: ",
            .networkRequestFailedPrefix: "Network request failed: ",
            .apiRequestFailedPrefix: "API request failed: HTTP ",
            .malformedAIJSONRetry: "AI returned malformed JSON. Click Retry.",
            .failedSaveSettings: "Failed to save settings",
            .failedSaveAPIKey: "Failed to save API key",
            .invalidProviderTitle: "Invalid provider settings",
            .invalidProviderBaseURL: "Base URL / Endpoint must be a valid HTTPS OpenAI-compatible endpoint.",
            .invalidProviderModel: "Model cannot be empty.",
            .invalidHotkeyTitle: "Invalid hotkey",
            .invalidHotkeyMessage: "Use a supported letter shortcut such as Control+Command+S, Ctrl+Option+H, Command+Shift+H, or Option+H.",
            .hotkeyRegistrationFailedTitle: "Global shortcut unavailable",
            .hotkeyRegistrationFailedMessageFormat: "SayFlow could not register %@ (OSStatus %d). Open Settings -> General and choose another supported letter shortcut.",
            .exportFailed: "Export failed",
            .importFailed: "Import failed",
            .launchAtLoginFailed: "Launch at login failed",
            .updateAvailableTitle: "Update available",
            .updateAvailableMessageFormat: "SayFlow %@ is available on GitHub Releases.",
            .openReleasePage: "Open Release Page",
            .followMouse: "Follow mouse",
            .bottomLeft: "Bottom left",
            .center: "Center",
            .lastClosed: "Last closed position",
            .themeSystem: "System",
            .themeLight: "Light",
            .themeDark: "Dark"
        ],
        .chinese: [
            .appName: "言顺",
            .appOffline: "言顺 离线",
            .checkGrammar: "检查语法",
            .settingsMenu: "设置...",
            .quitMenu: "退出 言顺",
            .settingsTitle: "言顺 设置",
            .tabGeneral: "通用",
            .tabProviders: "提供商",
            .tabPrompts: "提示词",
            .tabDisplay: "显示",
            .tabObsidian: "Obsidian",
            .tabAbout: "关于",
            .launchAtLogin: "开机自启动",
            .autoCheckUpdates: "自动检查更新",
            .saveHotkey: "保存快捷键",
            .saveTimeout: "保存超时",
            .globalShortcut: "全局快捷键",
            .networkTimeout: "网络超时",
            .activeProvider: "当前提供商",
            .apiKey: "API Key",
            .baseURLEndpoint: "Base URL / Endpoint",
            .model: "模型",
            .temperature: "Temperature",
            .saveProvider: "保存提供商",
            .testProvider: "检测",
            .providerTestInProgress: "正在检测提供商...",
            .providerTestSucceededFormat: "检测通过：%@ endpoint，HTTP %d。",
            .providerTestFailedFormat: "检测失败：%@",
            .save: "保存",
            .testRun: "测试运行",
            .restoreDefault: "恢复默认",
            .export: "导出",
            .import: "导入",
            .consumesOneAPICall: "会消耗一次 API 调用。",
            .systemPrompt: "System",
            .userPrompt: "User",
            .popupPosition: "弹窗位置",
            .theme: "主题",
            .chooseMarkdown: "打开",
            .saveFileMenu: "保存文件",
            .noRecentMarkdownFiles: "暂无最近 Markdown 文件",
            .targetMarkdownFile: "目标 Markdown 文件",
            .timeZone: "时区",
            .writeTemplate: "写入模板",
            .saveObsidianSettings: "保存 Obsidian 设置",
            .invalidObsidianPathTitle: "Obsidian 路径无效",
            .invalidObsidianPathEmpty: "请选择一个绝对路径的 .md 文件。",
            .invalidObsidianPathRelative: "请使用 Markdown 文件的绝对路径。",
            .invalidObsidianPathNotMarkdown: "Obsidian 目标文件必须是 .md 文件。",
            .aboutName: "言顺",
            .aboutVersion: "版本 1.2.2",
            .aboutReleases: "Releases: https://github.com/ZhiPengH/sayflow-release/releases",
            .aboutShaNote: "每次 DMG 构建脚本都会打印 SHA-256 校验值。",
            .systemTimeZone: "跟随系统",
            .corrected: "Corrected",
            .retry: "重试",
            .rawResponse: "原始响应",
            .checkingGrammar: "正在检查语法...",
            .writeFallback: "写入",
            .writeTooltip: "快速写入 Obsidian",
            .copyFallback: "复制",
            .copyTooltip: "复制",
            .accept: "Accept",
            .acceptCopiedFallback: "无法替换原文，已将修改后的句子复制到剪贴板。",
            .goodToKnow: "Good to know",
            .replacedChangeFormat: "将 [%@] 替换为 [%@]",
            .networkUnavailableTitle: "网络不可用",
            .networkUnavailableMessage: "请连接网络后再触发言顺。",
            .accessibilityTitle: "需要辅助功能权限",
            .accessibilityMessage: "言顺需要辅助功能权限来读取并替换选中的文本。",
            .accessibilityOnboardingTitle: "允许言顺使用辅助功能",
            .accessibilityOnboardingMessage: "言顺只会用辅助功能读取你选中的文本，并在你点击 Accept 时替换原文。",
            .openSystemSettings: "打开系统设置",
            .notNow: "稍后",
            .noSelectedTextTitle: "没有选中文本",
            .noSelectedTextMessage: "请先选中英文文本，或复制文本后再触发言顺。",
            .noActiveProvider: "没有配置当前提供商。",
            .missingAPIKey: "缺少 API Key。请打开设置 -> 提供商。",
            .chooseObsidianFirst: "请先在设置 -> Obsidian 选择目标 Markdown 文件。",
            .writeFailedPrefix: "写入 Obsidian 失败：",
            .obsidianWriteNoPermission: "没有权限写入目标 Markdown 文件。",
            .obsidianWriteDiskFull: "磁盘空间不足，言顺无法写入目标 Markdown 文件。",
            .obsidianWritePathUnavailable: "目标路径不可用或无效。",
            .streamParseFailedPrefix: "AI 返回流解析失败：",
            .networkRequestFailedPrefix: "网络请求失败：",
            .apiRequestFailedPrefix: "API 请求失败：HTTP ",
            .malformedAIJSONRetry: "AI 返回格式异常，可点击重试",
            .failedSaveSettings: "保存设置失败",
            .failedSaveAPIKey: "保存 API Key 失败",
            .invalidProviderTitle: "提供商设置无效",
            .invalidProviderBaseURL: "Base URL / Endpoint 必须是有效的 HTTPS OpenAI 兼容端点。",
            .invalidProviderModel: "模型不能为空。",
            .invalidHotkeyTitle: "快捷键无效",
            .invalidHotkeyMessage: "请使用 Control+Command+S、Ctrl+Cmd+S 或 Option+H 这样的格式。",
            .hotkeyRegistrationFailedTitle: "全局快捷键不可用",
            .hotkeyRegistrationFailedMessageFormat: "言顺无法注册 %@（OSStatus %d）。请打开设置 -> 通用，换一个支持的字母快捷键。",
            .exportFailed: "导出失败",
            .importFailed: "导入失败",
            .launchAtLoginFailed: "开机自启动设置失败",
            .updateAvailableTitle: "发现新版本",
            .updateAvailableMessageFormat: "言顺 %@ 已在 GitHub Releases 发布。",
            .openReleasePage: "打开 Release 页面",
            .followMouse: "跟随鼠标",
            .bottomLeft: "屏幕左下角",
            .center: "屏幕中央",
            .lastClosed: "上次关闭位置",
            .themeSystem: "跟随系统",
            .themeLight: "浅色",
            .themeDark: "深色"
        ]
    ]
}
