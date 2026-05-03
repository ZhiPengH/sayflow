import Foundation

enum NetworkAvailabilityPresentationTests {
    static func mapsNetworkStatusToMenuAndStatusTitle() throws {
        try expectEqual(
            NetworkAvailabilityPresentation.presentation(isOnline: true, language: .english),
            NetworkAvailabilityPresentation(menuEnabled: true, statusTitle: "Graker")
        )
        try expectEqual(
            NetworkAvailabilityPresentation.presentation(isOnline: false, language: .english),
            NetworkAvailabilityPresentation(menuEnabled: false, statusTitle: "Graker Offline")
        )
        try expectEqual(
            NetworkAvailabilityPresentation.presentation(isOnline: false, language: .chinese),
            NetworkAvailabilityPresentation(menuEnabled: false, statusTitle: "Graker 离线")
        )
    }
}
