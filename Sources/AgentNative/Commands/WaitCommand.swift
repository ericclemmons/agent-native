import ArgumentParser
import Foundation

struct WaitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "wait",
        abstract: "Wait until an element matching filters appears"
    )

    @Argument(help: "App name")
    var app: String

    @Option(name: .shortAndLong, help: "Filter by role")
    var role: String?
    @Option(name: .shortAndLong, help: "Filter by title")
    var title: String?
    @Option(name: .shortAndLong, help: "Filter by label")
    var label: String?
    @Option(name: .shortAndLong, help: "Filter by identifier")
    var identifier: String?
    @Option(name: .long, help: "Timeout in seconds")
    var timeout: Double = 10.0
    @Option(name: .long, help: "Poll interval in seconds")
    var interval: Double = 0.5

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
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let results = AXEngine.findElements(
                root: element,
                role: role, title: title, label: label, identifier: identifier,
                maxResults: 1
            )

            if let (_, node) = results.first {
                struct WaitResult: Codable {
                    let found: Bool
                    let element: AXNode
                }
                let result = WaitResult(found: true, element: node)

                if format == .text {
                    print("Found: \(node.description)")
                } else {
                    Output.print(result, format: format)
                }
                return
            }

            Thread.sleep(forTimeInterval: interval)
        }

        let filterDesc = [
            role.map { "role=\($0)" },
            title.map { "title=\($0)" },
            label.map { "label=\($0)" },
            identifier.map { "id=\($0)" },
        ].compactMap { $0 }.joined(separator: ", ")

        throw AXError.timeout("No element matching [\(filterDesc)] found within \(timeout)s")
    }
}
