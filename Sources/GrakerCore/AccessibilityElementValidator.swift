import ApplicationServices
import Foundation

public enum AccessibilityElementValidator {
    public static func isAccessibilityElement(_ value: CFTypeRef) -> Bool {
        CFGetTypeID(value) == AXUIElementGetTypeID()
    }
}
