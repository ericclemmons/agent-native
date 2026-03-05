import AppKit
import Foundation

enum AppType {
    case chromiumBrowser
    case electron
    case safari
    case native
}

struct CDPTab: Codable {
    let id: String
    let title: String
    let url: String
    let webSocketDebuggerUrl: String?
    let type: String?
}

final class AppDetector {

    // MARK: - Known Chromium bundle IDs

    private static let chromiumBundleIDs: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "company.thebrowser.Browser",       // Arc
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "org.chromium.Chromium",
    ]

    // MARK: - Detect app type

    static func detect(_ app: NSRunningApplication) -> AppType {
        if let bundleID = app.bundleIdentifier {
            if chromiumBundleIDs.contains(bundleID) {
                return .chromiumBrowser
            }
            if bundleID == "com.apple.Safari" || bundleID == "com.apple.SafariTechnologyPreview" {
                return .safari
            }
        }

        // Check for Electron framework inside the app bundle
        if let bundleURL = app.bundleURL {
            let electronFramework = bundleURL
                .appendingPathComponent("Contents/Frameworks/Electron Framework.framework")
            if FileManager.default.fileExists(atPath: electronFramework.path) {
                return .electron
            }
        }

        return .native
    }

    // MARK: - CDP port scanning

    /// Try to find a running CDP debug port by probing known ports.
    static func findCDPPort(tryPorts: [Int] = [9222, 9229]) -> Int? {
        for port in tryPorts {
            if cdpTabs(port: port) != nil {
                return port
            }
        }
        return nil
    }

    /// Fetch the list of debuggable tabs from a CDP endpoint.
    static func cdpTabs(port: Int) -> [CDPTab]? {
        guard let url = URL(string: "http://localhost:\(port)/json") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2

        let semaphore = DispatchSemaphore(value: 0)
        var result: [CDPTab]?

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let data = data
            else { return }
            result = try? JSONDecoder().decode([CDPTab].self, from: data)
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 3)
        return result
    }

    // MARK: - Browser name mapping (reuse from JsCommand pattern)

    static func resolveAppName(_ name: String) -> String {
        switch name.lowercased() {
        case "chrome": return "Google Chrome"
        case "edge": return "Microsoft Edge"
        default: return name
        }
    }
}
