import ArgumentParser
import Foundation

struct AppsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apps",
        abstract: "List running GUI applications"
    )

    @Option(name: .long, help: "Output format: text or json")
    var format: OutputFormat = .text

    func run() throws {
        let apps = AXEngine.listApps()
        Output.print(apps, format: format)
    }
}
