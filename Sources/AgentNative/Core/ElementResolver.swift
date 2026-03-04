import ApplicationServices
import Foundation

/// Shared logic: resolve an element either by @ref or by app name + filter flags.
struct ElementResolver {
    static func resolve(
        app: String?,
        ref: String?,
        role: String?,
        title: String?,
        label: String?,
        identifier: String?,
        index: Int = 0
    ) throws -> (element: AXUIElement, node: AXNode, appName: String) {
        // Ref-based resolution
        if let ref = ref, ref.hasPrefix("@") {
            let (el, node) = try RefStore.resolve(ref: ref)
            return (el, node, "")
        }

        // Filter-based resolution
        guard let appName = app else {
            throw AXError.appNotFound("App name required when not using @ref")
        }

        guard AXEngine.checkAccess() else {
            AXEngine.requestAccess()
            throw AXError.accessDenied
        }

        guard let runningApp = AXEngine.findApp(appName) else {
            throw AXError.appNotFound(appName)
        }

        runningApp.activate()
        Thread.sleep(forTimeInterval: 0.3)

        let appElement = AXEngine.appElement(pid: runningApp.processIdentifier)
        let results = AXEngine.findElements(
            root: appElement,
            role: role, title: title, label: label, identifier: identifier
        )

        guard index < results.count else {
            let msg = "Found \(results.count) matches, requested index \(index)"
            throw AXError.elementNotFound(msg)
        }

        let (target, node) = results[index]
        return (target, node, runningApp.localizedName ?? appName)
    }
}
