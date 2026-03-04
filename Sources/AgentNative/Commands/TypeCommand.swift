import ArgumentParser
import Foundation

struct TypeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "type",
        abstract: "Type text into an element (sets value without clearing)"
    )

    @Argument(help: "Target: @ref or app name")
    var target: String

    @Argument(help: "Text to type")
    var text: String

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
        let searchRole = isRef ? nil : (role ?? "TextField")

        let (el, node, _) = try ElementResolver.resolve(
            app: isRef ? nil : target,
            ref: isRef ? target : nil,
            role: searchRole,
            title: title, label: label, identifier: identifier,
            index: index
        )

        AXEngine.setFocus(el)
        Thread.sleep(forTimeInterval: 0.1)
        let success = AXEngine.setValue(el, value: text)

        struct TypeResult: Codable {
            let action: String; let success: Bool; let text: String; let element: AXNode
        }
        if json {
            Output.print(
                TypeResult(action: "setValue", success: success, text: text, element: node),
                format: .json)
        } else {
            print("\(success ? "OK" : "FAIL") Typed \"\(text)\" into: \(node.description)")
        }
        if !success { throw AXError.actionFailed("setValue", node.path) }
    }
}
