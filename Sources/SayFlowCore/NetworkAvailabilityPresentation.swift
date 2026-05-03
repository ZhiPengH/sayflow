import Foundation

public struct NetworkAvailabilityPresentation: Equatable {
    public var menuEnabled: Bool
    public var statusTitle: String

    public init(menuEnabled: Bool, statusTitle: String) {
        self.menuEnabled = menuEnabled
        self.statusTitle = statusTitle
    }

    public static func presentation(isOnline: Bool, language: AppLanguage = .preferred()) -> NetworkAvailabilityPresentation {
        NetworkAvailabilityPresentation(
            menuEnabled: isOnline,
            statusTitle: isOnline ? L10n.tr(.appName, language: language) : L10n.tr(.appOffline, language: language)
        )
    }
}
