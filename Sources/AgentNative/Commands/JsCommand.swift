import ArgumentParser
import Foundation

struct JsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "js",
        abstract: "Execute JavaScript in a browser's active tab",
        discussion: """
            Runs JavaScript via Apple Events in the active tab.
            Supports Arc, Chrome, and Safari.

              agent-native js Arc "document.title"
              agent-native js Safari "document.querySelectorAll('button').length"
            """
    )

    @Argument(help: "Browser app name (Arc, Google Chrome, Safari)")
    var app: String

    @Argument(help: "JavaScript code to execute")
    var code: String

    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let result = try executeJS(app: app, code: code)

        if json {
            struct JsResult: Codable {
                let app: String
                let result: String
            }
            Output.print(
                JsResult(app: app, result: result),
                format: .json
            )
        } else {
            print(result)
        }
    }

    private func executeJS(app: String, code: String) throws -> String {
        let script: String
        let appName = resolveAppName(app)

        switch appName.lowercased() {
        case "safari":
            script = """
            tell application "\(appName)" to do JavaScript "\(escapeForAppleScript(code))" in current tab of window 1
            """
        default:
            // Arc, Google Chrome, Chromium, Brave, Edge — all use the same Chromium syntax
            script = """
            tell application "\(appName)" to execute active tab of window 1 javascript "\(escapeForAppleScript(code))"
            """
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
            if errStr.contains("Allow JavaScript from Apple Events") {
                throw AXError.actionFailed("js", "Enable 'Allow JavaScript from Apple Events' in \(appName)'s developer settings")
            }
            throw AXError.actionFailed("js", errStr)
        }

        return String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func resolveAppName(_ name: String) -> String {
        switch name.lowercased() {
        case "chrome": return "Google Chrome"
        case "edge": return "Microsoft Edge"
        default: return name
        }
    }

    private func escapeForAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
