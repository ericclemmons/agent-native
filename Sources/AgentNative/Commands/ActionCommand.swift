import ArgumentParser
import Foundation

struct ActionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "action",
        abstract: "Perform an arbitrary AX action on an element"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Argument(help: "Action to perform (e.g. AXPress, AXConfirm, AXIncrement)")
    var action: String

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

        let available = AXEngine.actions(el)
        if !available.contains(action) {
            print("Warning: '\(action)' not in available actions: \(available)")
        }

        let success = AXEngine.performAction(el, action: action)

        struct ActionResult: Codable {
            let action: String; let success: Bool; let element: AXNode
        }
        if json {
            Output.print(
                ActionResult(action: action, success: success, element: node), format: .json)
        } else {
            print("\(success ? "OK" : "FAIL") \(action) on: \(node.description)")
        }
        if !success { throw AXError.actionFailed(action, node.path) }
    }
}
