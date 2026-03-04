import ApplicationServices
import ArgumentParser
import Foundation

struct IsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "is",
        abstract: "Check element state",
        subcommands: [IsEnabled.self, IsFocused.self]
    )
}

struct IsEnabled: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "enabled",
        abstract: "Check if an element is enabled"
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
        let (el, _, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: role, title: title, label: label, identifier: nil, index: index
        )
        let enabled = AXEngine.boolAttr(el, kAXEnabledAttribute as String)
        struct Result: Codable { let enabled: Bool }
        if json { Output.print(Result(enabled: enabled), format: .json) }
        else { print(enabled) }
    }
}

struct IsFocused: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "focused",
        abstract: "Check if an element is focused"
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
        let (el, _, _) = try ElementResolver.resolve(
            app: isRef ? nil : target, ref: isRef ? target : nil,
            role: role, title: title, label: label, identifier: nil, index: index
        )
        let focused = AXEngine.boolAttr(el, kAXFocusedAttribute as String)
        struct Result: Codable { let focused: Bool }
        if json { Output.print(Result(focused: focused), format: .json) }
        else { print(focused) }
    }
}
