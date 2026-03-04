import ArgumentParser
import Foundation

enum OutputFormat: String, CaseIterable, ExpressibleByArgument {
    case text
    case json
}

struct Output {
    static let jsonEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    static func print<T: Encodable>(_ value: T, format: OutputFormat) {
        switch format {
        case .json:
            if let data = try? jsonEncoder.encode(value),
               let str = String(data: data, encoding: .utf8)
            {
                Swift.print(str)
            }
        case .text:
            if let node = value as? AXNode {
                Swift.print(node.description)
            } else if let nodes = value as? [AXNode] {
                for n in nodes { Swift.print(n.description) }
            } else if let apps = value as? [AXEngine.AppInfo] {
                for app in apps {
                    let active = app.isActive ? " (active)" : ""
                    let hidden = app.isHidden ? " (hidden)" : ""
                    Swift.print("  \(app.name)  pid=\(app.pid)  \(app.bundleId ?? "")\(active)\(hidden)")
                }
            } else {
                // Fallback to JSON
                if let data = try? jsonEncoder.encode(value),
                   let str = String(data: data, encoding: .utf8)
                {
                    Swift.print(str)
                }
            }
        }
    }

    static func printTree(_ entries: [(node: AXNode, depth: Int)], format: OutputFormat) {
        switch format {
        case .json:
            let nodes = entries.map(\.node)
            if let data = try? jsonEncoder.encode(nodes),
               let str = String(data: data, encoding: .utf8)
            {
                Swift.print(str)
            }
        case .text:
            for (node, depth) in entries {
                let indent = String(repeating: "  ", count: depth)
                let actionStr = node.actions.isEmpty ? "" : " [\(node.actions.joined(separator: ", "))]"
                var desc = "\(indent)\(node.role)"
                if let t = node.title { desc += " \"\(t)\"" }
                else if let l = node.label { desc += " (\(l))" }
                if let v = node.value {
                    let truncated = v.count > 40 ? String(v.prefix(40)) + "..." : v
                    desc += " = \"\(truncated)\""
                }
                desc += actionStr
                if node.childCount > 0 { desc += "  > \(node.childCount) children" }
                Swift.print(desc)
            }
        }
    }
}
