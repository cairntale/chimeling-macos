import AppKit
import UniformTypeIdentifiers

enum AppBundle {
    static func identifier(at url: URL) -> String? {
        guard url.pathExtension.compare("app", options: .caseInsensitive) == .orderedSame,
            let identifier = Bundle(url: url)?.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
            !identifier.isEmpty
        else { return nil }
        return identifier
    }

    static func name(for identifier: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier),
            let bundle = Bundle(url: url)
        else { return identifier }
        for key in ["CFBundleDisplayName", "CFBundleName"] {
            guard let value = bundle.object(forInfoDictionaryKey: key) as? String else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return identifier
    }

    static func icon(for identifier: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .application)
    }
}
