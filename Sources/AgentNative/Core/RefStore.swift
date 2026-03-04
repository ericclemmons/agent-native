import ApplicationServices
import Foundation

/// Persists snapshot refs (@n1 -> element locator) to a temp JSON file
/// so they survive between CLI invocations (each command is a separate process).
final class RefStore {
    struct RefEntry: Codable {
        let ref: String
        let pid: Int32
        let role: String
        let title: String?
        let label: String?
        let identifier: String?
        let pathHint: String
    }

    private static let storePath: URL = {
        let tmp = FileManager.default.temporaryDirectory
        return tmp.appendingPathComponent("agent-native-refs.json")
    }()

    static func save(_ entries: [RefEntry]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(entries) {
            try? data.write(to: storePath)
        }
    }

    static func load() -> [RefEntry] {
        guard let data = try? Data(contentsOf: storePath),
            let entries = try? JSONDecoder().decode([RefEntry].self, from: data)
        else { return [] }
        return entries
    }

    /// Resolve "@n5" back to a live AXUIElement by re-walking the tree.
    static func resolve(ref: String) throws -> (element: AXUIElement, node: AXNode) {
        let entries = load()
        let cleanRef = ref.hasPrefix("@") ? String(ref.dropFirst()) : ref

        guard let entry = entries.first(where: { $0.ref == cleanRef }) else {
            throw AXError.elementNotFound("Unknown ref: @\(cleanRef). Run `snapshot` first.")
        }

        let appElement = AXEngine.appElement(pid: entry.pid)
        let results = AXEngine.findElements(
            root: appElement,
            role: entry.role.isEmpty ? nil : entry.role,
            title: entry.title,
            label: entry.label,
            identifier: entry.identifier,
            maxDepth: 15,
            maxResults: 50
        )

        // Exact match first
        if let match = results.first(where: { _, node in
            node.role == entry.role
                && node.title == entry.title
                && node.label == entry.label
                && node.identifier == entry.identifier
        }) {
            return match
        }

        // Fallback: first result
        if let match = results.first {
            return match
        }

        throw AXError.elementNotFound(
            "Could not re-resolve @\(cleanRef). The UI may have changed -- run `snapshot` again.")
    }
}
