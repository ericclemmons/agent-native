import ApplicationServices
import ArgumentParser
import Foundation

struct GetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get text, value, or attribute from an element",
        subcommands: [GetText.self, GetValue.self, GetAttr.self, GetTitle.self]
    )
}

struct GetText: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "text",
        abstract: "Get the text content of an element"
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

        let text =
            AXEngine.stringAttr(el, kAXValueAttribute as String)
            ?? AXEngine.stringAttr(el, kAXTitleAttribute as String)
            ?? AXEngine.stringAttr(el, kAXDescriptionAttribute as String)
            ?? ""

        struct GetResult: Codable { let text: String; let element: AXNode }
        if json {
            Output.print(GetResult(text: text, element: node), format: .json)
        } else {
            print(text)
        }
    }
}

struct GetValue: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "value",
        abstract: "Get the value of an input element"
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

        var rawVal: AnyObject?
        AXUIElementCopyAttributeValue(el, kAXValueAttribute as String as CFString, &rawVal)
        let value: String
        if let s = rawVal as? String { value = s }
        else if let n = rawVal as? NSNumber { value = n.stringValue }
        else { value = "" }

        struct GetResult: Codable { let value: String; let element: AXNode }
        if json {
            Output.print(GetResult(value: value, element: node), format: .json)
        } else {
            print(value)
        }
    }
}

struct GetAttr: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "attr",
        abstract: "Get a specific attribute of an element"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Argument(help: "Attribute name (e.g. AXRole, AXValue, AXEnabled)")
    var attribute: String

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

        var rawVal: AnyObject?
        AXUIElementCopyAttributeValue(el, attribute as CFString, &rawVal)
        let value: String
        if let s = rawVal as? String { value = s }
        else if let n = rawVal as? NSNumber { value = n.stringValue }
        else if let arr = rawVal as? [AnyObject] { value = "[\(arr.count) items]" }
        else { value = rawVal.map { String(describing: $0) } ?? "(nil)" }

        struct GetResult: Codable { let attribute: String; let value: String; let element: AXNode }
        if json {
            Output.print(
                GetResult(attribute: attribute, value: value, element: node), format: .json)
        } else {
            print(value)
        }
    }
}

struct GetTitle: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "title",
        abstract: "Get the title of the frontmost window of an app"
    )

    @Argument(help: "App name")
    var app: String

    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        guard let runningApp = AXEngine.findApp(app) else {
            throw AXError.appNotFound(app)
        }
        let el = AXEngine.appElement(pid: runningApp.processIdentifier)
        let windows: [AXUIElement] = AXEngine.children(el).filter {
            AXEngine.stringAttr($0, kAXRoleAttribute as String) == "AXWindow"
        }
        let title =
            windows.first.flatMap { AXEngine.stringAttr($0, kAXTitleAttribute as String) } ?? ""

        struct TitleResult: Codable { let title: String }
        if json {
            Output.print(TitleResult(title: title), format: .json)
        } else {
            print(title)
        }
    }
}
