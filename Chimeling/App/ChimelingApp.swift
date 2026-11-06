import ClerkKit
import Sparkle
import SwiftUI

@main
struct ChimelingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let updaterController: SPUStandardUpdaterController

    init() {
        Clerk.configure(publishableKey: ChimelingEnvironment.current.clerkPublishableKey)
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(
                service: appDelegate.presenceService,
                updater: updaterController.updater
            )
                .environment(Clerk.shared)
                .environment(appDelegate.settingsNavigation)
        } label: {
            MenuBarIconLabel(service: appDelegate.presenceService)
                .environment(Clerk.shared)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(updater: updaterController.updater)
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
