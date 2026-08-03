import Foundation

enum PrivateFilePermissions {
    static func restrictToOwner(_ fileURL: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }
}
