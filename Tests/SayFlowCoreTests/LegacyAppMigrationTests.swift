import Foundation

enum LegacyAppMigrationTests {
    static func copiesMissingLegacySettingsAndPromptsWithoutOverwritingNewFiles() throws {
        let directory = try TemporaryDirectory()
        let legacy = directory.url.appendingPathComponent(LegacyProductIdentity.applicationSupportDirectoryName)
        let current = directory.url.appendingPathComponent("SayFlow")
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
        try "legacy settings".write(to: legacy.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)
        try "legacy prompts".write(to: legacy.appendingPathComponent("prompts.json"), atomically: true, encoding: .utf8)
        try "new settings".write(to: current.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)

        try LegacyAppSupportMigration.copyMissingFiles(from: legacy, to: current)

        try expectEqual(
            try String(contentsOf: current.appendingPathComponent("settings.json"), encoding: .utf8),
            "new settings"
        )
        try expectEqual(
            try String(contentsOf: current.appendingPathComponent("prompts.json"), encoding: .utf8),
            "legacy prompts"
        )
    }

    static func migratesOnlyMissingProviderSecretsThatExistInLegacyKeychain() throws {
        let providers = AppSettings.defaults().providers
        let openAIReference = try unwrap(providers.first(where: { $0.kind == .openAI })?.apiKeyReference)
        let mimoReference = try unwrap(providers.first(where: { $0.kind == .mimo })?.apiKeyReference)
        let deepSeekReference = try unwrap(providers.first(where: { $0.kind == .deepSeek })?.apiKeyReference)

        let references = LegacyKeychainMigrationPolicy.referencesToMigrate(
            providers: providers,
            newSecretExists: { $0 == mimoReference },
            legacySecretExists: { $0 == openAIReference || $0 == mimoReference || $0 == deepSeekReference }
        )

        try expectEqual(references, [openAIReference, deepSeekReference])
    }
}
