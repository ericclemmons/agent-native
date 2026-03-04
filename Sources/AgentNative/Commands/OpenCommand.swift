import ArgumentParser
import Foundation

struct OpenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "open",
        abstract: "Open/launch an application by name or bundle ID"
    )

    @Argument(help: "App name or bundle identifier")
    var app: String

    @Option(name: .long, help: "Output format: text or json")
    var format: OutputFormat = .text

    func run() throws {
        let pid = try AXEngine.openApp(app)

        struct Result: Codable {
            let app: String
            let pid: Int32
            let status: String
        }

        let result = Result(app: app, pid: pid, status: "launched")
        if format == .json {
            Output.print(result, format: .json)
        } else {
            print("Opened \(app) (pid \(pid))")
        }
    }
}
