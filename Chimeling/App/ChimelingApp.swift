import AppKit
import ClerkKit
import SwiftUI

@main
struct ChimelingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        Clerk.configure(publishableKey: ChimelingEnvironment.current.clerkPublishableKey)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(service: appDelegate.presenceService)
                .environment(Clerk.shared)
                .environment(appDelegate.settingsNavigation)
        } label: {
            Image(nsImage: Self.menuBarIcon)
                .accessibilityLabel("Chimeling")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(Clerk.shared)
                .environment(appDelegate.settingsNavigation)
                .environment(appDelegate.presenceService)
                .onOpenURL { url in
                    Task {
                        try? await Clerk.shared.handle(url)
                    }
                }
        }
        .windowResizability(.contentSize)
    }

    /// 804pt SVG canvas; MenuBarExtra ignores SwiftUI `.frame`, so size the NSImage instead.
    private static let menuBarIcon: NSImage = {
        let image = (NSImage(named: "MenuBarIcon")?.copy() as? NSImage) ?? NSImage()
        image.size = NSSize(width: 16, height: 16)
        switch ChimelingEnvironment.current {
        case .development:
            return debugIcon(from: image)
        case .production:
            image.isTemplate = true
            return image
        }
    }()

    private static func debugIcon(from image: NSImage) -> NSImage {
        let composed = NSImage(size: image.size, flipped: false) { rect in
            NSColor.labelColor.set()
            rect.fill()
            image.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)

            let diameter: CGFloat = 5
            let knockout: CGFloat = 1
            let padding: CGFloat = 0
            let badgeRect = NSRect(
                x: rect.maxX - diameter - padding,
                y: rect.maxY - diameter - padding,
                width: diameter,
                height: diameter
            )
            let knockoutRect = badgeRect.insetBy(dx: -knockout, dy: -knockout)

            guard let context = NSGraphicsContext.current else { return false }
            context.saveGraphicsState()
            context.compositingOperation = .destinationOut
            NSColor.black.set()
            NSBezierPath(ovalIn: knockoutRect).fill()
            context.restoreGraphicsState()

            NSColor.systemOrange.set()
            NSBezierPath(ovalIn: badgeRect).fill()
            return true
        }
        composed.isTemplate = false
        return composed
    }
}
