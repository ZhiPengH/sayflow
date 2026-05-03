import Foundation

enum LocalizationTests {
    static func languageResolutionFollowsSystemPreferredLanguageOrder() throws {
        try expectEqual(AppLanguage.preferred(from: ["zh-Hans-US", "en-US"]), .chinese)
        try expectEqual(AppLanguage.preferred(from: ["en-US", "zh-Hans"]), .english)
        try expectEqual(AppLanguage.preferred(from: []), .english)
    }

    static func keyUiStringsHaveChineseAndEnglishTranslations() throws {
        try expectEqual(L10n.tr(.settingsTitle, language: .english), "Graker Settings")
        try expectEqual(L10n.tr(.settingsTitle, language: .chinese), "Graker 设置")
        try expectEqual(L10n.tr(.copyTooltip, language: .english), "Copy")
        try expectEqual(L10n.tr(.copyTooltip, language: .chinese), "复制")
    }

    static func everyKeyHasBothLanguages() throws {
        for key in L10nKey.allCases {
            try expect(!L10n.tr(key, language: .english).isEmpty, "Missing English translation for \(key)")
            try expect(!L10n.tr(key, language: .chinese).isEmpty, "Missing Chinese translation for \(key)")
        }
    }
}
