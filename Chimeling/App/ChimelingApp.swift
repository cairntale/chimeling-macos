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
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()
}
