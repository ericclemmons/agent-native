import AppKit
import ArgumentParser
import Foundation

struct PasteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "paste",
        abstract: "Paste clipboard contents or a file into an app via Cmd+V",
        discussion: """
            Supports three input modes:
              agent-native paste Arc                   # paste current clipboard
              agent-native paste Arc < image.png       # pipe file to clipboard, then paste
              agent-native paste Arc path/to/image.png # copy file to clipboard, then paste
            """
    )

    @Argument(help: "App name or bundle identifier")
    var app: String

    @Argument(help: "Path to file to paste (omit to paste clipboard or stdin)")
    var path: String?

    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        var description: String

        if let path = path {
            // Mode: file path argument
            let fileURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw AXError.elementNotFound("File not found: \(path)")
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            try copyFileToPasteboard(fileURL, pasteboard: pasteboard)
            description = fileURL.lastPathComponent
        } else if isatty(fileno(stdin)) == 0 {
            // Mode: stdin pipe
            let data = FileHandle.standardInput.readDataToEndOfFile()
            guard !data.isEmpty else {
                throw AXError.actionFailed("paste", "No input provided on stdin")
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.declareTypes([.png, .tiff], owner: nil)
            pasteboard.setData(data, forType: .png)
            if let image = NSImage(data: data),
               let tiff = image.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
            description = "stdin (\(data.count) bytes)"
        } else {
            // Mode: paste current clipboard
            description = "clipboard"
        }

        // Activate app and paste
        guard let runningApp = AXEngine.findApp(app) else {
            throw AXError.appNotFound(app)
        }
        runningApp.activate()
        Thread.sleep(forTimeInterval: 0.5)

        sendPaste()

        if json {
            struct PasteResult: Codable {
                let action: String
                let app: String
                let source: String
                let success: Bool
            }
            Output.print(
                PasteResult(action: "paste", app: self.app, source: description, success: true),
                format: .json
            )
        } else {
            print("OK Pasted \(description) into \(app)")
        }
    }

    private func copyFileToPasteboard(_ fileURL: URL, pasteboard: NSPasteboard) throws {
        let ext = fileURL.pathExtension.lowercased()
        let isImage = ["png", "jpg", "jpeg", "gif", "tiff", "tif", "bmp", "webp"].contains(ext)

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
    }

    private func sendPaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        else { return }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.05)
        keyUp.post(tap: .cghidEventTap)
    }
}
