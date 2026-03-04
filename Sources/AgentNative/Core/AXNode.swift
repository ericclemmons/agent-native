import Foundation

/// Lightweight, serializable representation of an AXUIElement node.
struct AXNode: Codable, CustomStringConvertible {
    let role: String
    let subrole: String?
    let title: String?
    let value: String?
    let label: String?       // AXDescription
    let identifier: String?  // AXIdentifier
    let enabled: Bool
    let focused: Bool
    let x: Double?
    let y: Double?
    let width: Double?
    let height: Double?
    let path: String         // e.g. /AXWindow/AXButton[@title="OK"]
    let actions: [String]
    let childCount: Int

    var description: String {
        var parts: [String] = [role]
        if let title = title { parts.append("title=\"\(title)\"") }
        if let label = label { parts.append("label=\"\(label)\"") }
        if let value = value {
            let truncated = value.count > 60 ? String(value.prefix(60)) + "..." : value
            parts.append("value=\"\(truncated)\"")
        }
        if let identifier = identifier { parts.append("id=\"\(identifier)\"") }
        if !enabled { parts.append("disabled") }
        if focused { parts.append("focused") }
        if !actions.isEmpty { parts.append("actions=[\(actions.joined(separator: ","))]") }
        return parts.joined(separator: " ")
    }
}
