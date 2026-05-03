import Foundation

enum AppSettingsTests {
    static func defaultSettingsMatchProductDefaults() throws {
        let settings = AppSettings.defaults()

        try expectEqual(settings.general.launchAtLogin, false)
        try expectEqual(settings.general.hotKey, HotKeyConfiguration.defaultOptionG)
        try expectEqual(settings.general.networkTimeoutSeconds, 30)
        try expectEqual(settings.display.positionStrategy, .followMouse)
        try expectEqual(settings.display.theme, .system)
        try expectEqual(settings.providers.filter(\.isActive).count, 1)
        try expectEqual(settings.providers.first(where: { $0.kind == .openAI })?.isActive, true)
        try expectEqual(settings.prompts, .defaultGrammarCorrection)
        try expectEqual(settings.obsidian.writeTemplate, .defaultObsidian)
        try expectNil(settings.obsidian.targetMarkdownPath)
    }

    static func settingsStoreCreatesAndReloadsDefaults() throws {
        let directory = try TemporaryDirectory()
        let store = AppSettingsStore(applicationSupportDirectory: directory.url)

        let loaded = try store.load()
        try expectEqual(loaded, AppSettings.defaults())
        try expect(FileManager.default.fileExists(atPath: directory.url.appendingPathComponent("settings.json").path))

        var changed = loaded
        changed.display.positionStrategy = .bottomLeft
        changed.obsidian.targetMarkdownPath = "/tmp/Graker-Inbox.md"
        try store.save(changed)

        try expectEqual(try store.load(), changed)
    }

    static func settingsStoreNeverSerializesPlaintextAPIKeys() throws {
        let directory = try TemporaryDirectory()
        let store = AppSettingsStore(applicationSupportDirectory: directory.url)
        var settings = AppSettings.defaults()
        settings.providers[0].apiKeyPlaintextForTesting = "sk-do-not-write"

        try store.save(settings)

        let raw = try String(contentsOf: store.fileURL, encoding: .utf8)
        try expect(!raw.contains("sk-do-not-write"))
        try expect(!raw.contains("apiKeyPlaintextForTesting"))
        try expectNil(try store.load().providers[0].apiKeyPlaintextForTesting)
    }

    static func settingsStoreDoesNotSerializePromptTemplates() throws {
        let directory = try TemporaryDirectory()
        let store = AppSettingsStore(applicationSupportDirectory: directory.url)
        var settings = AppSettings.defaults()
        settings.prompts = PromptTemplate(system: "Custom system", user: "Fix {{text}}")

        try store.save(settings)

        let raw = try String(contentsOf: store.fileURL, encoding: .utf8)
        try expect(!raw.contains("\"prompts\""))
        try expect(!raw.contains("Custom system"))
        try expectEqual(try store.load().prompts, .defaultGrammarCorrection)
    }

    static func settingsStoreCanReadLegacySettingsThatContainPrompts() throws {
        let directory = try TemporaryDirectory()
        let store = AppSettingsStore(applicationSupportDirectory: directory.url)
        let legacy = AppSettings.defaults()
        let data = try JSONEncoder().encode(legacy)
        try FileManager.default.createDirectory(at: directory.url, withIntermediateDirectories: true)
        try data.write(to: store.fileURL)

        let loaded = try store.load()

        try expectEqual(loaded.general.hotKey, .defaultOptionG)
        try expectEqual(loaded.prompts, .defaultGrammarCorrection)
    }

    static func settingsStoreNormalizesMultipleActiveProvidersOnLoad() throws {
        let directory = try TemporaryDirectory()
        let store = AppSettingsStore(applicationSupportDirectory: directory.url)
        var settings = AppSettings.defaults()
        settings.providers[0].isActive = true
        settings.providers[1].isActive = true

        try store.save(settings)
        let loaded = try store.load()

        try expectEqual(loaded.providers.filter(\.isActive).count, 1)
        try expectEqual(loaded.providers[0].isActive, true)
        try expectEqual(loaded.providers[1].isActive, false)
    }

    static func settingsStoreActivatesFirstProviderWhenNoneAreActive() throws {
        let directory = try TemporaryDirectory()
        let store = AppSettingsStore(applicationSupportDirectory: directory.url)
        var settings = AppSettings.defaults()
        for index in settings.providers.indices {
            settings.providers[index].isActive = false
        }

        try store.save(settings)
        let loaded = try store.load()

        try expectEqual(loaded.providers.filter(\.isActive).count, 1)
        try expectEqual(loaded.providers.first?.isActive, true)
    }

    static func settingsStoreRestoresMissingDefaultProvidersOnLoad() throws {
        let directory = try TemporaryDirectory()
        let store = AppSettingsStore(applicationSupportDirectory: directory.url)
        var settings = AppSettings.defaults()
        settings.providers = [settings.providers[0]]
        settings.providers[0].model = "custom-openai-model"
        settings.providers[0].baseURL = "https://proxy.example.com/v1"

        try store.save(settings)
        let loaded = try store.load()

        try expectEqual(loaded.providers.map(\.kind), ProviderCatalog.defaultProviders.map(\.kind))
        try expectEqual(loaded.providers.first?.model, "custom-openai-model")
        try expectEqual(loaded.providers.first?.baseURL, "https://proxy.example.com/v1")
        try expectEqual(loaded.providers.filter(\.isActive).count, 1)
    }

    static func settingsStoreMigratesLegacyMimoDefaultBaseURLWithoutOverwritingCustomURL() throws {
        let directory = try TemporaryDirectory()
        let store = AppSettingsStore(applicationSupportDirectory: directory.url)
        var settings = AppSettings.defaults()
        let mimoIndex = try unwrap(settings.providers.firstIndex(where: { $0.kind == .mimo }))
        settings.providers[mimoIndex].baseURL = "https://api.mimo.mi.com/v1"

        try store.save(settings)
        let migrated = try store.load()

        try expectEqual(
            migrated.providers.first(where: { $0.kind == .mimo })?.baseURL,
            "https://api.mimo-v2.com/v1"
        )

        settings.providers[mimoIndex].baseURL = "https://custom-mimo.example.com/v1"
        try store.save(settings)
        let custom = try store.load()

        try expectEqual(
            custom.providers.first(where: { $0.kind == .mimo })?.baseURL,
            "https://custom-mimo.example.com/v1"
        )
    }

    static func generalSettingsClampExternallyEditedNetworkTimeout() throws {
        let low = try decodeGeneralSettings(networkTimeoutSeconds: 0)
        let high = try decodeGeneralSettings(networkTimeoutSeconds: 999)

        try expectEqual(low.networkTimeoutSeconds, 5)
        try expectEqual(high.networkTimeoutSeconds, 120)
    }

    static func launchAtLoginToggleKeepsPreviousSettingWhenSystemChangeFails() throws {
        try expectEqual(
            LaunchAtLoginTogglePolicy.resolvedSetting(requested: true, previous: false, systemChangeSucceeded: false),
            false
        )
        try expectEqual(
            LaunchAtLoginTogglePolicy.resolvedSetting(requested: false, previous: true, systemChangeSucceeded: false),
            true
        )
        try expectEqual(
            LaunchAtLoginTogglePolicy.resolvedSetting(requested: true, previous: false, systemChangeSucceeded: true),
            true
        )
    }

    private static func decodeGeneralSettings(networkTimeoutSeconds: Int) throws -> GeneralSettings {
        let json = """
        {
          "launchAtLogin": false,
          "hotKey": {"displayText": "⌥G", "keyCode": 5, "modifierFlags": 2048},
          "automaticallyChecksForUpdates": false,
          "networkTimeoutSeconds": \(networkTimeoutSeconds)
        }
        """
        return try JSONDecoder().decode(GeneralSettings.self, from: Data(json.utf8))
    }
}
