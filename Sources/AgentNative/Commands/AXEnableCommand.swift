import ArgumentParser
import ApplicationServices
import Foundation

struct AXEnableCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ax-enable",
        abstract: "Enable enhanced accessibility for Chromium/Electron apps"
    )

    @Argument(help: "App name")
    var app: String

    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        guard AXEngine.checkAccess() else {
            AXEngine.requestAccess()
            throw AXError.accessDenied
        }

        guard let runningApp = AXEngine.findApp(app) else {
            throw AXError.appNotFound(app)
        }

        let pid = runningApp.processIdentifier
        let appType = AppDetector.detect(runningApp)
        let appName = runningApp.localizedName ?? app

        let enhanceType: AXEnhanceType
        switch appType {
        case .chromiumBrowser, .electron:
            enhanceType = .enhancedUserInterface
        case .safari:
            enhanceType = .enhancedUserInterface
        case .native:
            enhanceType = .enhancedUserInterface
        }

        guard let previousValue = AXEnhancer.enable(pid: pid, type: enhanceType) else {
            throw AXError.actionFailed("ax-enable", "Failed to set \(enhanceType.rawValue) on \(appName)")
        }

        struct EnableResult: Codable {
            let app: String
            let pid: Int32
            let attribute: String
            let enabled: Bool
            let previousValue: Bool
        }

        let result = EnableResult(
            app: appName,
            pid: pid,
            attribute: enhanceType.rawValue,
            enabled: true,
            previousValue: previousValue
        )

        if json {
            Output.print(result, format: .json)
        } else {
            print("Enabled \(enhanceType.rawValue) on \(appName) (pid \(pid))")
            if previousValue {
                print("  (was already enabled)")
            }
        }
    }
}

struct AXDisableCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ax-disable",
        abstract: "Disable enhanced accessibility for Chromium/Electron apps"
    )

    @Argument(help: "App name")
    var app: String

    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        guard AXEngine.checkAccess() else {
            AXEngine.requestAccess()
            throw AXError.accessDenied
        }

        guard let runningApp = AXEngine.findApp(app) else {
            throw AXError.appNotFound(app)
        }

        let pid = runningApp.processIdentifier
        let appName = runningApp.localizedName ?? app

        AXEnhancer.restore(pid: pid, type: .enhancedUserInterface, originalValue: false)

        struct DisableResult: Codable {
            let app: String
            let pid: Int32
            let attribute: String
            let enabled: Bool
        }

        let result = DisableResult(
            app: appName,
            pid: pid,
            attribute: AXEnhanceType.enhancedUserInterface.rawValue,
            enabled: false
        )

        if json {
            Output.print(result, format: .json)
        } else {
            print("Disabled \(AXEnhanceType.enhancedUserInterface.rawValue) on \(appName) (pid \(pid))")
        }
    }
}
