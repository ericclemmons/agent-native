import ArgumentParser
import Foundation

struct TreeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tree",
        abstract: "Print the accessibility tree for an application"
    )

    @Argument(help: "App name")
    var app: String

    @Option(name: .shortAndLong, help: "Maximum tree depth")
    var depth: Int = 5

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
        let tree = AXEngine.walkTree(element, maxDepth: depth)

        if format == .text {
            print(
                "Accessibility tree for \(runningApp.localizedName ?? app) (pid \(runningApp.processIdentifier)):"
            )
            print(String(repeating: "-", count: 45))
        }

        Output.printTree(tree, format: format)
    }
}
