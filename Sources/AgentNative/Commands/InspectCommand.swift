import ApplicationServices
import ArgumentParser
import Foundation

struct InspectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "inspect",
        abstract: "Inspect all attributes and actions of an element"
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

        var attrNames: CFArray?
        AXUIElementCopyAttributeNames(el, &attrNames)
        let names = (attrNames as? [String]) ?? []

        var attrs: [String: String] = [:]
        for name in names {
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(el, name as CFString, &value)
            if result == .success, let v = value {
                if let s = v as? String { attrs[name] = s }
                else if let n = v as? NSNumber { attrs[name] = n.stringValue }
                else if let arr = v as? [AnyObject] { attrs[name] = "[\(arr.count) items]" }
                else { attrs[name] = String(describing: type(of: v)) }
            }
        }

        let actions = AXEngine.actions(el)

        struct InspectResult: Codable {
            let element: AXNode
            let attributes: [String: String]
            let actions: [String]
        }

        let result = InspectResult(element: node, attributes: attrs, actions: actions)

        if json {
            Output.print(result, format: .json)
        } else {
            print("Element: \(node.description)")
            print("Path: \(node.path)")
            print("--- Attributes ---")
            for (key, value) in attrs.sorted(by: { $0.key < $1.key }) {
                let truncated = value.count > 80 ? String(value.prefix(80)) + "..." : value
                print("  \(key): \(truncated)")
            }
            print("--- Actions ---")
            for action in actions { print("  \(action)") }
        }
    }
}
