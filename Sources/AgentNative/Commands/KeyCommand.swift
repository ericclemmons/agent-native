import ArgumentParser
import CoreGraphics
import Foundation

struct KeyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "key",
        abstract: "Send keystrokes to an app"
    )

    @Argument(help: "App name or bundle identifier")
    var app: String

    @Argument(parsing: .remaining, help: "Keys to send (e.g. cmd+k, escape, \"Hello world\")")
    var keys: [String]

    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    func run() throws {
        guard !keys.isEmpty else {
            throw ValidationError("At least one key argument is required")
        }

        // Find or launch the app
        guard let runningApp = AXEngine.findApp(app) else {
            throw AXError.appNotFound(app)
        }

        // Activate the app
        runningApp.activate()
        Thread.sleep(forTimeInterval: 0.2)

        let pid = runningApp.processIdentifier

        for key in keys {
            if key.contains("+") || KeyLookup.specialKeys[key.lowercased()] != nil {
                // Modifier combo or special key
                try sendKeyCombination(key, pid: pid)
            } else {
                // Plain text — type each character
                try typeText(key, pid: pid)
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        if json {
            struct KeyResult: Codable {
                let action: String
                let app: String
                let keys: [String]
                let success: Bool
            }
            Output.print(
                KeyResult(action: "key", app: self.app, keys: self.keys, success: true),
                format: .json
            )
        } else {
            print("OK Sent keys to \(app): \(keys.joined(separator: " "))")
        }
    }

    private func sendKeyCombination(_ combo: String, pid: Int32) throws {
        let parts = combo.split(separator: "+").map { String($0).lowercased() }

        var flags: CGEventFlags = []
        var keyName: String?

        for part in parts {
            switch part {
            case "cmd", "command": flags.insert(.maskCommand)
            case "ctrl", "control": flags.insert(.maskControl)
            case "alt", "option", "opt": flags.insert(.maskAlternate)
            case "shift": flags.insert(.maskShift)
            default: keyName = part
            }
        }

        guard let name = keyName else {
            throw ValidationError("No key specified in combo: \(combo)")
        }

        let keyCode = try resolveKeyCode(name)

        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            throw AXError.actionFailed("key", "Failed to create keyboard event")
        }

        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.postToPid(pid)
        keyUp.postToPid(pid)
    }

    private func typeText(_ text: String, pid: Int32) throws {
        let source = CGEventSource(stateID: .hidSystemState)

        for char in text {
            // Use CGEvent with UniChar for accurate character entry
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
                continue
            }
            var unichar = Array(String(char).utf16)
            event.keyboardSetUnicodeString(stringLength: unichar.count, unicodeString: &unichar)
            event.postToPid(pid)

            guard let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                continue
            }
            upEvent.postToPid(pid)
            Thread.sleep(forTimeInterval: 0.01)
        }
    }

    private func resolveKeyCode(_ name: String) throws -> CGKeyCode {
        if let code = KeyLookup.specialKeys[name.lowercased()] {
            return code
        }
        // Single character — look up key code
        if name.count == 1, let code = KeyLookup.charToKeyCode[Character(name.lowercased())] {
            return code
        }
        throw ValidationError("Unknown key: \(name)")
    }
}

// MARK: - Key code lookup tables

enum KeyLookup {
    static let specialKeys: [String: CGKeyCode] = [
        "return": 0x24,
        "enter": 0x24,
        "tab": 0x30,
        "space": 0x31,
        "delete": 0x33,
        "backspace": 0x33,
        "escape": 0x35,
        "esc": 0x35,
        "left": 0x7B,
        "right": 0x7C,
        "down": 0x7D,
        "up": 0x7E,
        "home": 0x73,
        "end": 0x77,
        "pageup": 0x74,
        "pagedown": 0x79,
        "f1": 0x7A,
        "f2": 0x78,
        "f3": 0x63,
        "f4": 0x76,
        "f5": 0x60,
        "f6": 0x61,
        "f7": 0x62,
        "f8": 0x64,
        "f9": 0x65,
        "f10": 0x6D,
        "f11": 0x67,
        "f12": 0x6F,
        "forwarddelete": 0x75,
    ]

    static let charToKeyCode: [Character: CGKeyCode] = [
        "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E,
        "f": 0x03, "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26,
        "k": 0x28, "l": 0x25, "m": 0x2E, "n": 0x2D, "o": 0x1F,
        "p": 0x23, "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11,
        "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07, "y": 0x10,
        "z": 0x06,
        "0": 0x1D, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15,
        "5": 0x17, "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19,
        "-": 0x1B, "=": 0x18, "[": 0x21, "]": 0x1E, "\\": 0x2A,
        ";": 0x29, "'": 0x27, ",": 0x2B, ".": 0x2F, "/": 0x2C,
        "`": 0x32,
    ]
}
