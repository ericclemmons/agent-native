import ArgumentParser
import CoreGraphics
import Foundation
import ImageIO

struct ScreenshotCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "screenshot",
        abstract: "Capture a screenshot of an app's frontmost window"
    )

    @Argument(help: "App name or bundle identifier")
    var app: String

    @Argument(help: "Output path (default: auto-generated temp file)")
    var path: String?

    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        // Find or launch the app
        guard let runningApp = AXEngine.findApp(app) else {
            throw AXError.appNotFound(app)
        }

        let pid = runningApp.processIdentifier

        // Get window ID for the app's frontmost window
        guard let windowID = AXEngine.windowID(pid: pid) else {
            throw AXError.elementNotFound("No window found for \(app)")
        }

        // Capture the window
        guard let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            throw AXError.actionFailed("screenshot", "Failed to capture window image")
        }

        // Write PNG
        let outputPath = path ?? {
            let tmpDir = FileManager.default.temporaryDirectory
            let name = "agent-native-\(ProcessInfo.processInfo.globallyUniqueString).png"
            return tmpDir.appendingPathComponent(name).path
        }()
        let url = URL(fileURLWithPath: outputPath)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw AXError.actionFailed("screenshot", "Failed to create image destination")
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw AXError.actionFailed("screenshot", "Failed to write PNG")
        }

        let width = image.width
        let height = image.height

        if json {
            struct ScreenshotResult: Codable {
                let path: String
                let width: Int
                let height: Int
            }
            Output.print(
                ScreenshotResult(path: outputPath, width: width, height: height),
                format: .json
            )
        } else {
            print(outputPath)
        }
    }
}
