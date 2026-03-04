import ApplicationServices
import ArgumentParser
import Foundation

// MARK: - Focus

struct FocusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "focus",
        abstract: "Focus an element"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .shortAndLong, help: "Filter by identifier")
    var identifier: String?
    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0
    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: role, title: title, label: label, identifier: identifier, index: index
        )
        let success = AXEngine.setFocus(el)

        struct FocusResult: Codable { let action: String; let success: Bool; let element: AXNode }
        if json {
            Output.print(
                FocusResult(action: "focus", success: success, element: node), format: .json)
        } else { print("\(success ? "OK" : "FAIL") Focused: \(node.description)") }
    }
}

// MARK: - Hover

struct HoverCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hover",
        abstract: "Hover an element (moves cursor to center)"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0
    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: role, title: title, label: label, identifier: nil, index: index
        )

        if let pos = AXEngine.position(el), let sz = AXEngine.size(el) {
            let center = CGPoint(x: pos.x + sz.width / 2, y: pos.y + sz.height / 2)
            CGWarpMouseCursorPosition(center)
        }

        struct HoverResult: Codable { let action: String; let element: AXNode }
        if json {
            Output.print(HoverResult(action: "hover", element: node), format: .json)
        } else { print("OK Hovered: \(node.description)") }
    }
}

// MARK: - Check / Uncheck

struct CheckCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Check a checkbox / toggle (idempotent)"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0
    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: isRef ? role : (role ?? "CheckBox"),
            title: title, label: label, identifier: nil, index: index
        )

        var rawVal: AnyObject?
        AXUIElementCopyAttributeValue(el, kAXValueAttribute as String as CFString, &rawVal)
        let currentValue = (rawVal as? NSNumber)?.intValue ?? 0

        var success = true
        if currentValue == 0 {
            success = AXEngine.performAction(el, action: kAXPressAction as String)
        }

        struct CheckResult: Codable { let action: String; let success: Bool; let element: AXNode }
        if json {
            Output.print(
                CheckResult(action: "check", success: success, element: node), format: .json)
        } else { print("\(success ? "OK" : "FAIL") Checked: \(node.description)") }
    }
}

struct UncheckCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "uncheck",
        abstract: "Uncheck a checkbox / toggle (idempotent)"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0
    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: isRef ? role : (role ?? "CheckBox"),
            title: title, label: label, identifier: nil, index: index
        )

        var rawVal: AnyObject?
        AXUIElementCopyAttributeValue(el, kAXValueAttribute as String as CFString, &rawVal)
        let currentValue = (rawVal as? NSNumber)?.intValue ?? 0

        var success = true
        if currentValue == 1 {
            success = AXEngine.performAction(el, action: kAXPressAction as String)
        }

        struct UncheckResult: Codable {
            let action: String; let success: Bool; let element: AXNode
        }
        if json {
            Output.print(
                UncheckResult(action: "uncheck", success: success, element: node), format: .json)
        } else { print("\(success ? "OK" : "FAIL") Unchecked: \(node.description)") }
    }
}

// MARK: - Fill

struct FillCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fill",
        abstract: "Clear a field and type new text"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Argument(help: "Text to fill")
    var text: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0
    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: isRef ? nil : (role ?? "TextField"),
            title: title, label: label, identifier: nil, index: index
        )

        AXEngine.setFocus(el)
        Thread.sleep(forTimeInterval: 0.1)

        AXEngine.setValue(el, value: "")
        let success = AXEngine.setValue(el, value: text)

        struct FillResult: Codable {
            let action: String; let success: Bool; let text: String; let element: AXNode
        }
        if json {
            Output.print(
                FillResult(action: "fill", success: success, text: text, element: node),
                format: .json)
        } else {
            print("\(success ? "OK" : "FAIL") Filled: \(node.description) with \"\(text)\"")
        }
    }
}

// MARK: - Select

struct SelectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "select",
        abstract: "Select an option from a popup button / combo box"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Argument(help: "Option to select (by title)")
    var option: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .long, help: "Which match (0-indexed)")
    var index: Int = 0
    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let isRef = target.hasPrefix("@")
        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: isRef ? nil : (role ?? "PopUpButton"),
            title: title, label: label, identifier: nil, index: index
        )

        AXEngine.performAction(el, action: kAXPressAction as String)
        Thread.sleep(forTimeInterval: 0.5)

        let menuItems = AXEngine.findElements(
            root: el,
            role: "AXMenuItem",
            title: option,
            maxDepth: 5,
            maxResults: 1
        )

        var success = false
        if let (menuItem, _) = menuItems.first {
            success = AXEngine.performAction(menuItem, action: kAXPressAction as String)
        }

        struct SelectResult: Codable {
            let action: String; let success: Bool; let option: String; let element: AXNode
        }
        if json {
            Output.print(
                SelectResult(action: "select", success: success, option: option, element: node),
                format: .json)
        } else {
            print(
                "\(success ? "OK" : "FAIL") Selected \"\(option)\" in: \(node.description)")
        }
    }
}
