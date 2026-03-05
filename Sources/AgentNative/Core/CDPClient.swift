import Foundation

// MARK: - CDP AX Node (from Accessibility.getFullAXTree)

struct CDPAXNode: Codable {
    let nodeId: String
    let role: CDPAXValue?
    let name: CDPAXValue?
    let description: CDPAXValue?
    let value: CDPAXValue?
    let childIds: [String]?
    let properties: [CDPAXProperty]?
    let ignored: Bool?

    struct CDPAXValue: Codable {
        let type: String?
        let value: AnyCodableValue?
    }

    struct CDPAXProperty: Codable {
        let name: String
        let value: CDPAXValue
    }
}

/// A simple JSON value wrapper for CDP responses.
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { self = .string(s) }
        else if let b = try? container.decode(Bool.self) { self = .bool(b) }
        else if let i = try? container.decode(Int.self) { self = .int(i) }
        else if let d = try? container.decode(Double.self) { self = .double(d) }
        else if container.decodeNil() { self = .null }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return b ? "true" : "false"
        case .null: return nil
        }
    }
}

// MARK: - CDP Client

final class CDPClient {
    let port: Int

    init(port: Int) {
        self.port = port
    }

    /// List debuggable tabs.
    func listTabs() throws -> [CDPTab] {
        guard let tabs = AppDetector.cdpTabs(port: port) else {
            throw CDPError.connectionFailed(port)
        }
        return tabs
    }

    /// Get the full accessibility tree for a tab via WebSocket.
    func getFullAXTree(tab: CDPTab) throws -> [CDPAXNode] {
        guard let wsURLString = tab.webSocketDebuggerUrl,
              let wsURL = URL(string: wsURLString)
        else {
            throw CDPError.noWebSocket(tab.id)
        }

        let session = URLSession(configuration: .default)
        let wsTask = session.webSocketTask(with: wsURL)
        wsTask.resume()

        defer {
            wsTask.cancel(with: .goingAway, reason: nil)
        }

        // 1. Send Accessibility.enable
        try sendAndReceive(wsTask, method: "Accessibility.enable", id: 1)

        // 2. Send Accessibility.getFullAXTree
        let responseData = try sendAndReceive(wsTask, method: "Accessibility.getFullAXTree", id: 2)

        // Parse the result.nodes array
        struct AXTreeResponse: Codable {
            let id: Int
            let result: AXTreeResult?

            struct AXTreeResult: Codable {
                let nodes: [CDPAXNode]
            }
        }

        let response = try JSONDecoder().decode(AXTreeResponse.self, from: responseData)
        guard let nodes = response.result?.nodes else {
            throw CDPError.noNodes
        }

        return nodes
    }

    /// Convert CDP AX nodes into the same (AXNode, depth) format used by walkTree.
    func convertToAXNodes(_ cdpNodes: [CDPAXNode]) -> [(node: AXNode, depth: Int)] {
        // Build parent->children map and find root
        var childMap: [String: [String]] = [:]
        var nodeMap: [String: CDPAXNode] = [:]

        for node in cdpNodes {
            nodeMap[node.nodeId] = node
            if let children = node.childIds {
                childMap[node.nodeId] = children
            }
        }

        // Find root (first node, or node not referenced as a child)
        let allChildIds = Set(cdpNodes.flatMap { $0.childIds ?? [] })
        let rootId = cdpNodes.first(where: { !allChildIds.contains($0.nodeId) })?.nodeId
            ?? cdpNodes.first?.nodeId

        guard let rootId = rootId else { return [] }

        // DFS to build flat list with depths
        var results: [(node: AXNode, depth: Int)] = []
        var visited = Set<String>()

        func dfs(_ nodeId: String, depth: Int, parentPath: String) {
            guard !visited.contains(nodeId), let cdpNode = nodeMap[nodeId] else { return }
            visited.insert(nodeId)

            // Skip ignored nodes
            if cdpNode.ignored == true {
                // Still visit children
                for childId in childMap[nodeId] ?? [] {
                    dfs(childId, depth: depth, parentPath: parentPath)
                }
                return
            }

            let role = mapCDPRole(cdpNode.role?.value?.stringValue ?? "unknown")
            let name = cdpNode.name?.value?.stringValue
            let value = cdpNode.value?.value?.stringValue
            let desc = cdpNode.description?.value?.stringValue

            // Build path segment
            var segment = role
            if let n = name { segment += "[@title=\"\(n)\"]" }
            let fullPath = parentPath.isEmpty ? "/\(segment)" : "\(parentPath)/\(segment)"

            // Extract properties
            let focused = cdpNode.properties?.first(where: { $0.name == "focused" })?.value.value
            let isFocused = {
                if case .bool(let b) = focused { return b }
                return false
            }()

            let disabled = cdpNode.properties?.first(where: { $0.name == "disabled" })?.value.value
            let isDisabled = {
                if case .bool(let b) = disabled { return b }
                return false
            }()

            let axNode = AXNode(
                role: role,
                subrole: nil,
                title: name,
                value: value,
                label: desc,
                identifier: nil,
                enabled: !isDisabled,
                focused: isFocused,
                x: nil, y: nil, width: nil, height: nil,
                path: fullPath,
                actions: actionsForRole(role),
                childCount: (childMap[nodeId] ?? []).count
            )

            results.append((node: axNode, depth: depth))

            for childId in childMap[nodeId] ?? [] {
                dfs(childId, depth: depth + 1, parentPath: fullPath)
            }
        }

        dfs(rootId, depth: 0, parentPath: "")
        return results
    }

    // MARK: - Private

    @discardableResult
    private func sendAndReceive(_ wsTask: URLSessionWebSocketTask, method: String, id: Int) throws -> Data {
        let semaphore = DispatchSemaphore(value: 0)
        var resultData: Data?
        var resultError: Error?

        // Send
        let message: [String: Any] = ["id": id, "method": method, "params": [:] as [String: Any]]
        let jsonData = try JSONSerialization.data(withJSONObject: message)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        wsTask.send(.string(jsonString)) { error in
            if let error = error {
                resultError = error
                semaphore.signal()
                return
            }

            // Receive
            wsTask.receive { result in
                switch result {
                case .success(let msg):
                    switch msg {
                    case .string(let text):
                        resultData = text.data(using: .utf8)
                    case .data(let data):
                        resultData = data
                    @unknown default:
                        break
                    }
                case .failure(let error):
                    resultError = error
                }
                semaphore.signal()
            }
        }

        let timeout = semaphore.wait(timeout: .now() + 10)
        if timeout == .timedOut { throw CDPError.timeout }
        if let error = resultError { throw CDPError.webSocketError(error.localizedDescription) }
        return resultData ?? Data()
    }

    /// Map CDP accessibility roles to macOS AX roles.
    private func mapCDPRole(_ cdpRole: String) -> String {
        switch cdpRole.lowercased() {
        case "rootwebarea": return "AXWebArea"
        case "button": return "AXButton"
        case "link": return "AXLink"
        case "textbox", "searchbox": return "AXTextField"
        case "textarea": return "AXTextArea"
        case "checkbox": return "AXCheckBox"
        case "radiobutton": return "AXRadioButton"
        case "combobox", "listbox": return "AXComboBox"
        case "menubar": return "AXMenuBar"
        case "menu": return "AXMenu"
        case "menuitem": return "AXMenuItem"
        case "tab": return "AXTab"
        case "tablist": return "AXTabGroup"
        case "heading": return "AXHeading"
        case "image", "img": return "AXImage"
        case "slider": return "AXSlider"
        case "switch", "toggle": return "AXSwitch"
        case "table": return "AXTable"
        case "row": return "AXRow"
        case "cell", "gridcell": return "AXCell"
        case "navigation": return "AXGroup"
        case "region", "section", "article", "main", "complementary", "contentinfo",
             "banner", "form": return "AXGroup"
        case "list": return "AXList"
        case "listitem": return "AXGroup"
        case "dialog": return "AXSheet"
        case "alertdialog", "alert": return "AXSheet"
        case "tree": return "AXOutline"
        case "treeitem": return "AXRow"
        case "progressbar": return "AXProgressIndicator"
        case "statictext": return "AXStaticText"
        case "generic", "none": return "AXGroup"
        default: return "AX\(cdpRole.prefix(1).uppercased())\(cdpRole.dropFirst())"
        }
    }

    /// Infer likely AX actions from a role.
    private func actionsForRole(_ role: String) -> [String] {
        switch role {
        case "AXButton", "AXLink", "AXMenuItem", "AXTab", "AXSwitch":
            return ["AXPress"]
        case "AXCheckBox", "AXRadioButton":
            return ["AXPress"]
        case "AXTextField", "AXTextArea", "AXComboBox":
            return ["AXPress", "AXConfirm"]
        case "AXSlider":
            return ["AXIncrement", "AXDecrement"]
        default:
            return []
        }
    }
}

// MARK: - Errors

enum CDPError: Error, CustomStringConvertible {
    case connectionFailed(Int)
    case noWebSocket(String)
    case noNodes
    case timeout
    case webSocketError(String)

    var description: String {
        switch self {
        case .connectionFailed(let port):
            return "Cannot connect to CDP on port \(port). Launch browser with --remote-debugging-port=\(port)"
        case .noWebSocket(let id):
            return "Tab \(id) has no webSocketDebuggerUrl"
        case .noNodes:
            return "CDP returned no accessibility nodes"
        case .timeout:
            return "CDP WebSocket timed out"
        case .webSocketError(let msg):
            return "CDP WebSocket error: \(msg)"
        }
    }
}
