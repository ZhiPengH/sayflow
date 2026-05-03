import Foundation

enum NetworkAvailabilityPresentationTests {
    static func mapsNetworkStatusToMenuAndStatusTitle() throws {
        try expectEqual(
            NetworkAvailabilityPresentation.presentation(isOnline: true, language: .english),
            NetworkAvailabilityPresentation(menuEnabled: true, statusTitle: "SayFlow")
        )
        try expectEqual(
            NetworkAvailabilityPresentation.presentation(isOnline: false, language: .english),
            NetworkAvailabilityPresentation(menuEnabled: false, statusTitle: "SayFlow Offline")
        )
        try expectEqual(
            NetworkAvailabilityPresentation.presentation(isOnline: false, language: .chinese),
            NetworkAvailabilityPresentation(menuEnabled: false, statusTitle: "言顺 离线")
        )
    }
}
