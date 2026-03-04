import ApplicationServices
import ArgumentParser
import Foundation

struct ClickCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "click",
        abstract: "Click (AXPress) an element. Use @ref or filter flags."
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
            app: isRef ? nil : target,
            ref: isRef ? target : nil,
            role: role, title: title, label: label, identifier: identifier,
            index: index
        )

        let acted = AXEngine.performAction(el, action: kAXPressAction as String)
            || AXEngine.performAction(el, action: kAXConfirmAction as String)

        struct ClickResult: Codable {
            let action: String; let success: Bool; let element: AXNode
        }
        if json {
            Output.print(
                ClickResult(action: "AXPress", success: acted, element: node), format: .json)
        } else {
            print("\(acted ? "OK" : "FAIL") Clicked: \(node.description)")
        }
        if !acted { throw AXError.actionFailed("AXPress", node.path) }
    }
}
