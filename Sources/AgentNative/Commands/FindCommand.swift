import ArgumentParser
import Foundation

struct FindCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "find",
        abstract: "Find accessibility elements matching filters"
    )

    @Argument(help: "App name")
    var app: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?

    @Option(name: .shortAndLong, help: "Filter by title (substring)")
    var title: String?

    @Option(name: .shortAndLong, help: "Filter by label (substring)")
    var label: String?

    @Option(name: .shortAndLong, help: "Filter by identifier (substring)")
    var identifier: String?

    @Option(name: .shortAndLong, help: "Filter by value (substring)")
    var value: String?

    @Option(name: .long, help: "Max search depth")
    var depth: Int = 10

    @Option(name: .shortAndLong, help: "Max results")
    var max: Int = 20

    @Option(name: .long, help: "Output format: text or json")
    var format: OutputFormat = .text

    func run() throws {
        guard AXEngine.checkAccess() else {
            AXEngine.requestAccess()
            throw AXError.accessDenied
        }

        guard let runningApp = AXEngine.findApp(app) else {
            throw AXError.appNotFound(app)
        }

        let element = AXEngine.appElement(pid: runningApp.processIdentifier)
        let results = AXEngine.findElements(
            root: element,
            role: role, title: title, label: label,
            identifier: identifier, value: value,
            maxDepth: depth, maxResults: max
        )

        let nodes = results.map(\.node)

        if format == .text {
            print("Found \(nodes.count) element(s) in \(runningApp.localizedName ?? app):")
            print(String(repeating: "-", count: 45))
            for (i, node) in nodes.enumerated() {
                print("  [\(i)] \(node.description)")
                print("       path: \(node.path)")
            }
        } else {
            Output.print(nodes, format: format)
        }
    }
}
