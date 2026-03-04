import ArgumentParser
import ApplicationServices
import Foundation

struct SnapshotCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "snapshot",
        abstract: "Accessibility tree snapshot with refs (@n1, @n2) for interaction"
    )

    @Argument(help: "App name")
    var app: String

    @Flag(name: .shortAndLong, help: "Interactive elements only")
    var interactive: Bool = false

    @Flag(name: .shortAndLong, help: "Compact — remove empty structural elements")
    var compact: Bool = false

    @Option(name: .shortAndLong, help: "Max tree depth")
    var depth: Int = 8

    @Flag(name: .long, help: "JSON output")
    var json: Bool = false

    static let interactiveRoles: Set<String> = [
        "AXButton", "AXTextField", "AXTextArea", "AXCheckBox",
        "AXRadioButton", "AXPopUpButton", "AXComboBox", "AXSlider",
        "AXMenuButton", "AXLink", "AXTab", "AXMenuItem",
        "AXMenuBarItem", "AXSwitch", "AXToggle", "AXSearchField",
        "AXSecureTextField", "AXStepper", "AXDisclosureTriangle",
        "AXIncrementor", "AXColorWell", "AXSegmentedControl",
    ]

    func run() throws {
        guard AXEngine.checkAccess() else {
            AXEngine.requestAccess()
            throw AXError.accessDenied
        }

        guard let runningApp = AXEngine.findApp(app) else {
            throw AXError.appNotFound(app)
        }

        let pid = runningApp.processIdentifier
        let element = AXEngine.appElement(pid: pid)
        let tree = AXEngine.walkTree(element, maxDepth: depth)

        var refCounter = 0
        var refEntries: [RefStore.RefEntry] = []

        struct RefNode: Codable {
            let ref: String
            let role: String
            let title: String?
            let label: String?
            let value: String?
            let enabled: Bool
            let actions: [String]
            let depth: Int
        }

        var refNodes: [RefNode] = []

        for (node, d) in tree {
            if interactive && !Self.interactiveRoles.contains(node.role) {
                continue
            }
            if compact && node.title == nil && node.label == nil
                && node.value == nil && node.actions.isEmpty
                && node.childCount > 0
            {
                continue
            }

            refCounter += 1
            let ref = "n\(refCounter)"

            refEntries.append(
                RefStore.RefEntry(
                    ref: ref,
                    pid: pid,
                    role: node.role,
                    title: node.title,
                    label: node.label,
                    identifier: node.identifier,
                    pathHint: node.path
                ))

            refNodes.append(
                RefNode(
                    ref: ref,
                    role: node.role,
                    title: node.title,
                    label: node.label,
                    value: node.value,
                    enabled: node.enabled,
                    actions: node.actions,
                    depth: d
                ))
        }

        RefStore.save(refEntries)

        if json {
            if let data = try? Output.jsonEncoder.encode(refNodes),
                let str = String(data: data, encoding: .utf8)
            {
                print(str)
            }
        } else {
            let appName = runningApp.localizedName ?? app
            print("Snapshot: \(appName) (pid \(pid)) -- \(refNodes.count) elements")
            print(String(repeating: "-", count: 45))
            for rn in refNodes {
                let indent = String(repeating: "  ", count: rn.depth)
                var line = "\(indent)\(rn.role)"
                if let t = rn.title { line += " \"\(t)\"" }
                else if let l = rn.label { line += " (\(l))" }
                if let v = rn.value {
                    let truncated = v.count > 40 ? String(v.prefix(40)) + "..." : v
                    line += " = \"\(truncated)\""
                }
                if !rn.actions.isEmpty {
                    line += " [\(rn.actions.joined(separator: ", "))]"
                }
                line += " [ref=\(rn.ref)]"
                if !rn.enabled { line += " (disabled)" }
                print(line)
            }
        }
    }
}
