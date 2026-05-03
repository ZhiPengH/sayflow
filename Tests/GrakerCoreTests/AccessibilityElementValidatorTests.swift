import ApplicationServices
import Foundation

enum AccessibilityElementValidatorTests {
    static func acceptsAXUIElementValuesAndRejectsOtherCFTypes() throws {
        let systemWide = AXUIElementCreateSystemWide()
        let nonElement = "not an accessibility element" as CFTypeRef

        try expect(AccessibilityElementValidator.isAccessibilityElement(systemWide))
        try expect(!AccessibilityElementValidator.isAccessibilityElement(nonElement))
    }
}
