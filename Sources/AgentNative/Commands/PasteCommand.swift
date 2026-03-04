import AppKit
import ArgumentParser
import Foundation

struct PasteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "paste",
        abstract: "Copy a file to clipboard and paste (Cmd+V) into an app"
    )

    @Argument(help: "App name or bundle identifier")
    var app: String

    @Argument(help: "Path to file to paste")
    var path: String

    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        let fileURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw AXError.elementNotFound("File not found: \(path)")
        }

        let ext = fileURL.pathExtension.lowercased()
        let isImage = ["png", "jpg", "jpeg", "gif", "tiff", "tif", "bmp", "webp"].contains(ext)

        // Set clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if isImage {
            let data = try Data(contentsOf: fileURL)
            pasteboard.declareTypes([.png, .tiff], owner: nil)
            pasteboard.setData(data, forType: .png)
            if let image = NSImage(contentsOf: fileURL),
               let tiff = image.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
        } else {
            pasteboard.declareTypes([.fileURL], owner: nil)
            pasteboard.writeObjects([fileURL as NSURL])
        }

        // Activate app and wait for pasteboard to sync
        guard let runningApp = AXEngine.findApp(app) else {
            throw AXError.appNotFound(app)
        }
        runningApp.activate()
        Thread.sleep(forTimeInterval: 0.5)

        // Send Cmd+V via HID event tap (more reliable for Electron apps)
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        else {
            throw AXError.actionFailed("paste", "Failed to create keyboard event")
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.05)
        keyUp.post(tap: .cghidEventTap)

        if json {
            struct PasteResult: Codable {
                let action: String
                let app: String
                let path: String
                let success: Bool
            }
            Output.print(
                PasteResult(action: "paste", app: self.app, path: fileURL.path, success: true),
                format: .json
            )
        } else {
            print("OK Pasted \(fileURL.lastPathComponent) into \(app)")
        }
    }
}
