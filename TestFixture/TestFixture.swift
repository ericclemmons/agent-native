// TestFixture — minimal AppKit app with known AX elements for CI testing.
// Build:  swiftc -o TestFixture TestFixture.swift -framework Cocoa
// Run:    ./TestFixture &

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 400, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Agent Native Test Fixture"

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        let label = NSTextField(labelWithString: "Hello from TestFixture")
        label.frame = NSRect(x: 20, y: 340, width: 360, height: 24)
        label.accessibilityIdentifier = "greeting-label"
        contentView.addSubview(label)

        let textField = NSTextField(frame: NSRect(x: 20, y: 300, width: 260, height: 24))
        textField.placeholderString = "Type here"
        textField.accessibilityIdentifier = "main-input"
        textField.accessibilityLabel = "Main Input"
        contentView.addSubview(textField)

        let submitButton = NSButton(title: "Submit", target: self, action: #selector(submitClicked))
        submitButton.frame = NSRect(x: 290, y: 298, width: 90, height: 28)
        submitButton.accessibilityIdentifier = "submit-button"
        contentView.addSubview(submitButton)

        let resetButton = NSButton(title: "Reset", target: self, action: #selector(resetClicked))
        resetButton.frame = NSRect(x: 290, y: 260, width: 90, height: 28)
        resetButton.accessibilityIdentifier = "reset-button"
        contentView.addSubview(resetButton)

        let checkbox = NSButton(checkboxWithTitle: "Enable notifications", target: nil, action: nil)
        checkbox.frame = NSRect(x: 20, y: 260, width: 250, height: 24)
        checkbox.state = .off
        checkbox.accessibilityIdentifier = "notifications-checkbox"
        contentView.addSubview(checkbox)

        let checkbox2 = NSButton(checkboxWithTitle: "Dark mode", target: nil, action: nil)
        checkbox2.frame = NSRect(x: 20, y: 230, width: 250, height: 24)
        checkbox2.state = .on
        checkbox2.accessibilityIdentifier = "darkmode-checkbox"
        contentView.addSubview(checkbox2)

        let popup = NSPopUpButton(frame: NSRect(x: 20, y: 190, width: 200, height: 28))
        popup.addItems(withTitles: ["Option A", "Option B", "Option C"])
        popup.accessibilityIdentifier = "options-popup"
        contentView.addSubview(popup)

        let slider = NSSlider(value: 50, minValue: 0, maxValue: 100, target: nil, action: nil)
        slider.frame = NSRect(x: 20, y: 150, width: 260, height: 24)
        slider.accessibilityIdentifier = "volume-slider"
        slider.accessibilityLabel = "Volume"
        contentView.addSubview(slider)

        let statusLabel = NSTextField(labelWithString: "Status: idle")
        statusLabel.frame = NSRect(x: 20, y: 110, width: 360, height: 24)
        statusLabel.accessibilityIdentifier = "status-label"
        statusLabel.tag = 999
        contentView.addSubview(statusLabel)

        let disabledButton = NSButton(title: "Disabled Action", target: nil, action: nil)
        disabledButton.frame = NSRect(x: 20, y: 70, width: 150, height: 28)
        disabledButton.isEnabled = false
        disabledButton.accessibilityIdentifier = "disabled-button"
        contentView.addSubview(disabledButton)

        let searchField = NSSearchField(frame: NSRect(x: 20, y: 30, width: 260, height: 24))
        searchField.placeholderString = "Search..."
        searchField.accessibilityIdentifier = "search-field"
        contentView.addSubview(searchField)

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
    }

    @objc func submitClicked() {
        if let statusLabel = window.contentView?.viewWithTag(999) as? NSTextField {
            statusLabel.stringValue = "Status: submitted"
        }
    }

    @objc func resetClicked() {
        if let statusLabel = window.contentView?.viewWithTag(999) as? NSTextField {
            statusLabel.stringValue = "Status: reset"
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
