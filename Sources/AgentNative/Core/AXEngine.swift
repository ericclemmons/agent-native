import AppKit
import ApplicationServices
import CoreGraphics

// MARK: - Errors

enum AXError: Error, CustomStringConvertible {
    case appNotFound(String)
    case elementNotFound(String)
    case actionFailed(String, String)
    case accessDenied
    case timeout(String)

    var description: String {
        switch self {
        case .appNotFound(let name): return "App not found: \(name)"
        case .elementNotFound(let path): return "Element not found: \(path)"
        case .actionFailed(let action, let path): return "Action '\(action)' failed on: \(path)"
        case .accessDenied:
            return "Accessibility access denied. Enable in System Settings > Privacy & Security > Accessibility"
        case .timeout(let msg): return "Timeout: \(msg)"
        }
    }
}

// MARK: - Engine

final class AXEngine {

    // MARK: - App discovery

    struct AppInfo: Codable {
        let name: String
        let bundleId: String?
        let pid: Int32
        let isActive: Bool
        let isHidden: Bool
    }

    static func listApps() -> [AppInfo] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let name = app.localizedName else { return nil }
                return AppInfo(
                    name: name,
                    bundleId: app.bundleIdentifier,
                    pid: app.processIdentifier,
                    isActive: app.isActive,
                    isHidden: app.isHidden
                )
            }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Find a running app by name — case-insensitive prefix match, then substring fallback.
    static func findApp(_ query: String) -> NSRunningApplication? {
        let q = query.lowercased()
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
        return apps.first { ($0.localizedName ?? "").lowercased().hasPrefix(q) }
            ?? apps.first { ($0.localizedName ?? "").lowercased().contains(q) }
    }

    /// Launch an app by name or bundle ID, returns PID.
    /// If the app is already running, just activates it and returns its PID.
    static func openApp(_ nameOrBundleId: String) throws -> Int32 {
        // If already running, just activate and return
        if let existing = findApp(nameOrBundleId) {
            existing.activate()
            return existing.processIdentifier
        }

        // Try bundle ID first
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: nameOrBundleId) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            let semaphore = DispatchSemaphore(value: 0)
            var resultApp: NSRunningApplication?
            var resultError: (any Error)?
            NSWorkspace.shared.openApplication(at: url, configuration: config) { app, error in
                resultApp = app
                resultError = error
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 10)
            if let err = resultError { throw AXError.appNotFound("\(nameOrBundleId): \(err)") }
            if let app = resultApp { return app.processIdentifier }
        }

        // Try by name via `open -a`
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", nameOrBundleId]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw AXError.appNotFound(nameOrBundleId)
        }

        Thread.sleep(forTimeInterval: 1.0)

        // The app name may differ from what the user typed (e.g. "System Preferences"
        // launches "System Settings"). Try the query first, then fall back to the
        // frontmost app that just activated.
        if let app = findApp(nameOrBundleId) {
            return app.processIdentifier
        }

        // Fallback: return whichever regular app is currently active
        if let active = NSWorkspace.shared.runningApplications
            .first(where: { $0.isActive && $0.activationPolicy == .regular })
        {
            return active.processIdentifier
        }

        throw AXError.appNotFound(nameOrBundleId)
    }

    // MARK: - Window ID

    /// Find the CGWindowID for an app's frontmost window.
    static func windowID(pid: Int32) -> CGWindowID? {
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        // Find windows belonging to this PID, prefer the frontmost (lowest layer)
        let appWindows = windowList
            .filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }
            .filter { ($0[kCGWindowLayer as String] as? Int) == 0 } // normal window layer
        guard let window = appWindows.first,
              let id = window[kCGWindowNumber as String] as? CGWindowID
        else { return nil }
        return id
    }

    // MARK: - AX element helpers

    static func appElement(pid: Int32) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    static func attribute<T>(_ element: AXUIElement, _ attr: String) -> T? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard result == .success else { return nil }
        return value as? T
    }

    static func stringAttr(_ element: AXUIElement, _ attr: String) -> String? {
        attribute(element, attr)
    }

    static func boolAttr(_ element: AXUIElement, _ attr: String) -> Bool {
        var v: AnyObject?
        AXUIElementCopyAttributeValue(element, attr as CFString, &v)
        if let num = v as? NSNumber { return num.boolValue }
        return false
    }

    static func position(_ element: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            element, kAXPositionAttribute as String as CFString, &value)
        guard result == .success, let val = value else { return nil }
        var point = CGPoint.zero
        if AXValueGetValue(val as! AXValue, .cgPoint, &point) { return point }
        return nil
    }

    static func size(_ element: AXUIElement) -> CGSize? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            element, kAXSizeAttribute as String as CFString, &value)
        guard result == .success, let val = value else { return nil }
        var size = CGSize.zero
        if AXValueGetValue(val as! AXValue, .cgSize, &size) { return size }
        return nil
    }

    static func children(_ element: AXUIElement) -> [AXUIElement] {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            element, kAXChildrenAttribute as String as CFString, &value)
        guard result == .success, let arr = value as? [AXUIElement] else { return [] }
        return arr
    }

    static func actions(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        let result = AXUIElementCopyActionNames(element, &names)
        guard result == .success, let arr = names as? [String] else { return [] }
        return arr
    }

    // MARK: - Build tree

    static func nodeFrom(_ element: AXUIElement, path: String) -> AXNode {
        let role = stringAttr(element, kAXRoleAttribute as String) ?? "AXUnknown"
        let subrole = stringAttr(element, kAXSubroleAttribute as String)
        let title = stringAttr(element, kAXTitleAttribute as String)
        let label = stringAttr(element, kAXDescriptionAttribute as String)
        let identifier = stringAttr(element, kAXIdentifierAttribute as String)
        let enabled = boolAttr(element, kAXEnabledAttribute as String)
        let focused = boolAttr(element, kAXFocusedAttribute as String)

        var rawVal: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as String as CFString, &rawVal)
        let value: String? = rawVal.flatMap { v in
            if let s = v as? String { return s }
            if let n = v as? NSNumber { return n.stringValue }
            return nil
        }

        let pos = position(element)
        let sz = size(element)

        return AXNode(
            role: role,
            subrole: subrole,
            title: title,
            value: value,
            label: label,
            identifier: identifier,
            enabled: enabled,
            focused: focused,
            x: pos.map { Double($0.x) },
            y: pos.map { Double($0.y) },
            width: sz.map { Double($0.width) },
            height: sz.map { Double($0.height) },
            path: path,
            actions: actions(element),
            childCount: children(element).count
        )
    }

    /// Walk the AX tree, collecting (AXNode, depth) tuples.
    static func walkTree(
        _ element: AXUIElement,
        path: String = "",
        depth: Int = 0,
        maxDepth: Int = 5
    ) -> [(node: AXNode, depth: Int)] {
        let role = stringAttr(element, kAXRoleAttribute as String) ?? "AXUnknown"
        let title = stringAttr(element, kAXTitleAttribute as String)
        let label = stringAttr(element, kAXDescriptionAttribute as String)

        var segment = role
        if let t = title { segment += "[@title=\"\(t)\"]" }
        else if let l = label { segment += "[@label=\"\(l)\"]" }

        let fullPath = path.isEmpty ? "/\(segment)" : "\(path)/\(segment)"
        let node = nodeFrom(element, path: fullPath)
        var results: [(AXNode, Int)] = [(node, depth)]

        guard depth < maxDepth else { return results }

        var roleCounts: [String: Int] = [:]
        for child in children(element) {
            let childRole = stringAttr(child, kAXRoleAttribute as String) ?? "AXUnknown"
            let childTitle = stringAttr(child, kAXTitleAttribute as String)
            let childLabel = stringAttr(child, kAXDescriptionAttribute as String)

            var childSegment = childRole
            if let t = childTitle { childSegment += "[@title=\"\(t)\"]" }
            else if let l = childLabel { childSegment += "[@label=\"\(l)\"]" }

            let idx = roleCounts[childSegment, default: 0]
            roleCounts[childSegment] = idx + 1

            // Pass fullPath (this element's path) as parent for children
            results += walkTree(child, path: fullPath, depth: depth + 1, maxDepth: maxDepth)
        }

        return results
    }

    // MARK: - Find elements

    static func findElements(
        root: AXUIElement,
        role: String? = nil,
        title: String? = nil,
        label: String? = nil,
        identifier: String? = nil,
        value: String? = nil,
        maxDepth: Int = 10,
        maxResults: Int = 50
    ) -> [(element: AXUIElement, node: AXNode)] {
        var results: [(AXUIElement, AXNode)] = []
        findElementsRecursive(
            element: root, parentPath: "",
            role: role, title: title, label: label,
            identifier: identifier, value: value,
            depth: 0, maxDepth: maxDepth,
            maxResults: maxResults, results: &results
        )
        return results
    }

    private static func findElementsRecursive(
        element: AXUIElement,
        parentPath: String,
        role: String?,
        title: String?,
        label: String?,
        identifier: String?,
        value: String?,
        depth: Int,
        maxDepth: Int,
        maxResults: Int,
        results: inout [(AXUIElement, AXNode)]
    ) {
        guard results.count < maxResults, depth <= maxDepth else { return }

        let elemRole = stringAttr(element, kAXRoleAttribute as String) ?? "AXUnknown"
        let elemTitle = stringAttr(element, kAXTitleAttribute as String)
        let elemLabel = stringAttr(element, kAXDescriptionAttribute as String)
        let elemId = stringAttr(element, kAXIdentifierAttribute as String)

        var rawVal: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as String as CFString, &rawVal)
        let elemValue = (rawVal as? String) ?? (rawVal as? NSNumber)?.stringValue

        var segment = elemRole
        if let t = elemTitle { segment += "[@title=\"\(t)\"]" }
        let currentPath = parentPath.isEmpty ? "/\(segment)" : "\(parentPath)/\(segment)"

        // Check filters
        var matches = true
        if let r = role, !elemRole.lowercased().contains(r.lowercased()) { matches = false }
        if let t = title, !(elemTitle ?? "").lowercased().contains(t.lowercased()) { matches = false }
        if let l = label, !(elemLabel ?? "").lowercased().contains(l.lowercased()) { matches = false }
        if let i = identifier, !(elemId ?? "").lowercased().contains(i.lowercased()) {
            matches = false
        }
        if let v = value, !(elemValue ?? "").lowercased().contains(v.lowercased()) {
            matches = false
        }

        if matches && (role != nil || title != nil || label != nil || identifier != nil
            || value != nil)
        {
            let node = nodeFrom(element, path: currentPath)
            results.append((element, node))
        }

        for child in children(element) {
            findElementsRecursive(
                element: child, parentPath: currentPath,
                role: role, title: title, label: label,
                identifier: identifier, value: value,
                depth: depth + 1, maxDepth: maxDepth,
                maxResults: maxResults, results: &results
            )
        }
    }

    // MARK: - Actions

    @discardableResult
    static func performAction(_ element: AXUIElement, action: String) -> Bool {
        AXUIElementPerformAction(element, action as CFString) == .success
    }

    @discardableResult
    static func setValue(_ element: AXUIElement, value: String) -> Bool {
        AXUIElementSetAttributeValue(
            element, kAXValueAttribute as String as CFString, value as CFTypeRef) == .success
    }

    @discardableResult
    static func setFocus(_ element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(
            element, kAXFocusedAttribute as String as CFString, true as CFTypeRef) == .success
    }

    // MARK: - Access check

    static func checkAccess() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
