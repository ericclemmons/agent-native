import AppKit
import ApplicationServices
import Foundation

enum AXEnhanceType: String {
    case enhancedUserInterface = "AXEnhancedUserInterface"
    case manualAccessibility = "AXManualAccessibility"
}

final class AXEnhancer {

    /// Enable an accessibility enhancement attribute on a process.
    /// Returns the previous value so it can be restored, or nil on failure.
    @discardableResult
    static func enable(pid: Int32, type: AXEnhanceType) -> Bool? {
        let app = AXUIElementCreateApplication(pid)
        let attr = type.rawValue as CFString

        // Read previous value
        var oldValue: AnyObject?
        AXUIElementCopyAttributeValue(app, attr, &oldValue)
        let previousValue = (oldValue as? NSNumber)?.boolValue ?? false

        // Set to true
        let result = AXUIElementSetAttributeValue(app, attr, true as CFTypeRef)
        guard result == .success || result == .attributeUnsupported else {
            return nil
        }

        return previousValue
    }

    /// Restore a previously saved value for an accessibility attribute.
    static func restore(pid: Int32, type: AXEnhanceType, originalValue: Bool) {
        let app = AXUIElementCreateApplication(pid)
        let attr = type.rawValue as CFString
        AXUIElementSetAttributeValue(app, attr, originalValue as CFTypeRef)
    }

    /// Automatically enable the appropriate enhancement for a Chromium/Electron app.
    /// Returns a cleanup closure that restores the original value, or nil if not applicable.
    static func autoEnhance(_ app: NSRunningApplication) -> (() -> Void)? {
        let appType = AppDetector.detect(app)
        let pid = app.processIdentifier

        switch appType {
        case .chromiumBrowser, .electron:
            // AXEnhancedUserInterface is the standard Chromium attribute
            if let prev = enable(pid: pid, type: .enhancedUserInterface) {
                // Give the app time to build its accessibility tree
                Thread.sleep(forTimeInterval: 0.5)
                return {
                    restore(pid: pid, type: .enhancedUserInterface, originalValue: prev)
                }
            }
            // Fallback to AXManualAccessibility for older Chromium/Electron
            if let prev = enable(pid: pid, type: .manualAccessibility) {
                Thread.sleep(forTimeInterval: 0.5)
                return {
                    restore(pid: pid, type: .manualAccessibility, originalValue: prev)
                }
            }
            return nil

        case .safari, .native:
            return nil
        }
    }
}
