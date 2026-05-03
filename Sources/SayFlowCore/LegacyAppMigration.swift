import Foundation

public enum LegacyProductIdentity {
    public static let applicationSupportDirectoryName = "Graker"
    public static let keychainService = "Graker"
}

public enum LegacyAppSupportMigration {
    public static let defaultFileNames = ["settings.json", "prompts.json"]

    public static func copyMissingFiles(
        from legacyDirectory: URL,
        to currentDirectory: URL,
        fileNames: [String] = defaultFileNames,
        fileManager: FileManager = .default
    ) throws {
        guard fileManager.fileExists(atPath: legacyDirectory.path) else {
            return
        }
        try fileManager.createDirectory(at: currentDirectory, withIntermediateDirectories: true)
        for fileName in fileNames {
            let source = legacyDirectory.appendingPathComponent(fileName)
            let destination = currentDirectory.appendingPathComponent(fileName)
            guard fileManager.fileExists(atPath: source.path),
                  !fileManager.fileExists(atPath: destination.path) else {
                continue
            }
            try fileManager.copyItem(at: source, to: destination)
        }
    }
}

public enum LegacyKeychainMigrationPolicy {
    public static func referencesToMigrate(
        providers: [ProviderConfiguration],
        newSecretExists: (String) -> Bool,
        legacySecretExists: (String) -> Bool
    ) -> [String] {
        providers
            .map(\.apiKeyReference)
            .filter { reference in
                !newSecretExists(reference) && legacySecretExists(reference)
            }
    }
}
