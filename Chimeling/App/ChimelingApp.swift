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
            MenuBarIconLabel(service: appDelegate.presenceService)
                .environment(Clerk.shared)
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
}
