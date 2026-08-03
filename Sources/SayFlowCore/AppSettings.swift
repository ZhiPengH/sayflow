import Foundation

public struct HotKeyConfiguration: Codable, Equatable {
    public var displayText: String
    public var keyCode: UInt32
    public var modifierFlags: UInt32

    public init(displayText: String, keyCode: UInt32, modifierFlags: UInt32) {
        self.displayText = displayText
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }

    static let legacyDefaultOptionG = HotKeyConfiguration(
        displayText: "⌥G",
        keyCode: 5,
        modifierFlags: 1 << 11
    )

    public static let defaultControlCommandS = HotKeyConfiguration(
        displayText: "⌃⌘S",
        keyCode: 1,
        modifierFlags: (1 << 12) | (1 << 8)
    )

    static func migratedDefault(_ configuration: HotKeyConfiguration) -> HotKeyConfiguration {
        configuration == legacyDefaultOptionG ? .defaultControlCommandS : configuration
    }
}

public struct GeneralSettings: Codable, Equatable {
    public var launchAtLogin: Bool
    public var hotKey: HotKeyConfiguration
    public var automaticallyChecksForUpdates: Bool
    public var networkTimeoutSeconds: Int
    public var hasShownAccessibilityOnboarding: Bool

    public init(
        launchAtLogin: Bool,
        hotKey: HotKeyConfiguration,
        automaticallyChecksForUpdates: Bool,
        networkTimeoutSeconds: Int,
        hasShownAccessibilityOnboarding: Bool
    ) {
        self.launchAtLogin = launchAtLogin
        self.hotKey = hotKey
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        self.networkTimeoutSeconds = networkTimeoutSeconds
        self.hasShownAccessibilityOnboarding = hasShownAccessibilityOnboarding
    }

    enum CodingKeys: String, CodingKey {
        case launchAtLogin
        case hotKey
        case automaticallyChecksForUpdates
        case networkTimeoutSeconds
        case hasShownAccessibilityOnboarding
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        hotKey = HotKeyConfiguration.migratedDefault(try container.decode(HotKeyConfiguration.self, forKey: .hotKey))
        automaticallyChecksForUpdates = try container.decodeIfPresent(Bool.self, forKey: .automaticallyChecksForUpdates) ?? false
        let decodedTimeout = try container.decodeIfPresent(Int.self, forKey: .networkTimeoutSeconds) ?? 30
        networkTimeoutSeconds = min(max(decodedTimeout, 5), 120)
        hasShownAccessibilityOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasShownAccessibilityOnboarding) ?? true
    }
}

public enum LaunchAtLoginTogglePolicy {
    public static func resolvedSetting(requested: Bool, previous: Bool, systemChangeSucceeded: Bool) -> Bool {
        systemChangeSucceeded ? requested : previous
    }
}

public enum DisplayTheme: String, Codable, CaseIterable, Equatable {
    case light

    public init(from decoder: Decoder) throws {
        self = .light
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct DisplaySettings: Codable, Equatable {
    public var positionStrategy: PopupPositionStrategy
    public var theme: DisplayTheme

    public init(positionStrategy: PopupPositionStrategy, theme: DisplayTheme) {
        self.positionStrategy = positionStrategy
        self.theme = theme
    }
}

public struct ObsidianSettings: Codable, Equatable {
    public var targetMarkdownPath: String?
    public var recentMarkdownPaths: [String]
    public var writeTemplate: ObsidianTemplate
    public var timeZoneIdentifier: String?

    public init(
        targetMarkdownPath: String?,
        recentMarkdownPaths: [String] = [],
        writeTemplate: ObsidianTemplate,
        timeZoneIdentifier: String?
    ) {
        self.targetMarkdownPath = targetMarkdownPath
        self.recentMarkdownPaths = Array(recentMarkdownPaths.prefix(ObsidianRecentMarkdownFiles.limit))
        self.writeTemplate = writeTemplate
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    enum CodingKeys: String, CodingKey {
        case targetMarkdownPath
        case recentMarkdownPaths
        case writeTemplate
        case timeZoneIdentifier
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        targetMarkdownPath = try container.decodeIfPresent(String.self, forKey: .targetMarkdownPath)
        recentMarkdownPaths = Array(
            (try container.decodeIfPresent([String].self, forKey: .recentMarkdownPaths) ?? [])
                .prefix(ObsidianRecentMarkdownFiles.limit)
        )
        writeTemplate = try container.decode(ObsidianTemplate.self, forKey: .writeTemplate)
        timeZoneIdentifier = try container.decodeIfPresent(String.self, forKey: .timeZoneIdentifier)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(targetMarkdownPath, forKey: .targetMarkdownPath)
        try container.encode(recentMarkdownPaths, forKey: .recentMarkdownPaths)
        try container.encode(writeTemplate, forKey: .writeTemplate)
        try container.encodeIfPresent(timeZoneIdentifier, forKey: .timeZoneIdentifier)
    }

    public var timeZone: TimeZone {
        if let timeZoneIdentifier, let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            return timeZone
        }
        return .current
    }
}

public struct AppSettings: Codable, Equatable {
    public var general: GeneralSettings
    public var providers: [ProviderConfiguration]
    public var prompts: PromptTemplate
    public var display: DisplaySettings
    public var obsidian: ObsidianSettings

    public init(
        general: GeneralSettings,
        providers: [ProviderConfiguration],
        prompts: PromptTemplate,
        display: DisplaySettings,
        obsidian: ObsidianSettings
    ) {
        self.general = general
        self.providers = providers
        self.prompts = prompts
        self.display = display
        self.obsidian = obsidian
    }

    public static func defaults() -> AppSettings {
        AppSettings(
            general: GeneralSettings(
                launchAtLogin: false,
                hotKey: .defaultControlCommandS,
                automaticallyChecksForUpdates: false,
                networkTimeoutSeconds: 30,
                hasShownAccessibilityOnboarding: false
            ),
            providers: ProviderConfiguration.defaults(),
            prompts: .defaultGrammarCorrection,
            display: DisplaySettings(positionStrategy: .followMouse, theme: .light),
            obsidian: ObsidianSettings(
                targetMarkdownPath: nil,
                writeTemplate: .defaultObsidian,
                timeZoneIdentifier: nil
            )
        )
    }

    public var activeProvider: ProviderConfiguration? {
        providers.first(where: \.isActive)
    }

    enum CodingKeys: String, CodingKey {
        case general
        case providers
        case display
        case obsidian
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        general = try container.decode(GeneralSettings.self, forKey: .general)
        providers = try container.decode([ProviderConfiguration].self, forKey: .providers)
        providers = AppSettings.mergedWithDefaultProviders(providers)
        AppSettings.normalizeActiveProvider(in: &providers)
        prompts = .defaultGrammarCorrection
        display = try container.decode(DisplaySettings.self, forKey: .display)
        obsidian = try container.decode(ObsidianSettings.self, forKey: .obsidian)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(general, forKey: .general)
        try container.encode(providers, forKey: .providers)
        try container.encode(display, forKey: .display)
        try container.encode(obsidian, forKey: .obsidian)
    }

    private static func mergedWithDefaultProviders(_ decodedProviders: [ProviderConfiguration]) -> [ProviderConfiguration] {
        ProviderConfiguration.defaults().map { defaultProvider in
            guard let existing = decodedProviders.first(where: { $0.kind == defaultProvider.kind || $0.id == defaultProvider.id }) else {
                var added = defaultProvider
                added.isActive = false
                return added
            }
            var merged = defaultProvider
            merged.id = existing.id
            merged.displayName = existing.displayName.isEmpty ? defaultProvider.displayName : existing.displayName
            merged.apiKeyReference = ProviderSecretReference.normalized(existing.apiKeyReference, kind: defaultProvider.kind)
            merged.baseURL = ProviderLegacyDefaultMigrator.migratedBaseURL(
                kind: existing.kind,
                existingBaseURL: existing.baseURL,
                currentDefaultBaseURL: defaultProvider.baseURL
            )
            merged.model = ProviderLegacyDefaultMigrator.migratedModel(
                kind: existing.kind,
                existingModel: existing.model,
                currentDefaultModel: defaultProvider.model
            )
            merged.modelHistory = ProviderModelHistory.normalized(existing.modelHistory)
            merged.temperature = existing.temperature
            merged.isActive = existing.isActive
            return merged
        }
    }

    private static func normalizeActiveProvider(in providers: inout [ProviderConfiguration]) {
        guard !providers.isEmpty else {
            return
        }
        let activeIndex = providers.firstIndex(where: \.isActive) ?? providers.startIndex
        for index in providers.indices {
            providers[index].isActive = index == activeIndex
        }
    }
}

public enum ProviderLegacyDefaultMigrator {
    public static func migratedBaseURL(kind: ProviderKind, existingBaseURL: String, currentDefaultBaseURL: String) -> String {
        if kind == .deepSeek,
           existingBaseURL.trimmingCharacters(in: .whitespacesAndNewlines) == "https://api.deepseek.com/v1" {
            return currentDefaultBaseURL
        }
        if kind == .mimo,
           existingBaseURL.trimmingCharacters(in: .whitespacesAndNewlines) == "https://api.mimo.mi.com/v1" {
            return currentDefaultBaseURL
        }
        if kind == .miniMax,
           existingBaseURL.trimmingCharacters(in: .whitespacesAndNewlines) == "https://api.minimax.chat/v1" {
            return currentDefaultBaseURL
        }
        return existingBaseURL
    }

    public static func migratedModel(kind: ProviderKind, existingModel: String, currentDefaultModel: String) -> String {
        if kind == .miniMax,
           existingModel.trimmingCharacters(in: .whitespacesAndNewlines) == "abab6.5s-chat" {
            return currentDefaultModel
        }
        return existingModel
    }
}

public final class AppSettingsStore {
    public let applicationSupportDirectory: URL
    public let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(applicationSupportDirectory: URL) {
        self.applicationSupportDirectory = applicationSupportDirectory
        self.fileURL = applicationSupportDirectory.appendingPathComponent("settings.json")
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func load() throws -> AppSettings {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            let defaults = AppSettings.defaults()
            try save(defaults)
            return defaults
        }
        try PrivateFilePermissions.restrictToOwner(fileURL)
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(AppSettings.self, from: data)
    }

    public func save(_ settings: AppSettings) throws {
        try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
        try PrivateFilePermissions.restrictToOwner(fileURL)
    }
}
