import AppKit
import ClerkKit
import SwiftUI

@main
struct ChimelingApp: App {
    init() {
        Clerk.configure(publishableKey: ClerkPublishableKey.current)
    }

    var body: some Scene {
        MenuBarExtra("Chimeling", systemImage: "bell") {
            OpenSettingsButton()

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(Clerk.shared)
                .onOpenURL { url in
                    Task {
                        try? await Clerk.shared.handle(url)
                    }
                }
        }
        .windowResizability(.contentSize)
    }
}

struct OpenSettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // Do not use SettingsLink,
        // because SettingsLink does not activate an LSUIElement app, so the window stays behind.
        Button("Settings…") {
            NSApp.activate()
            openSettings()
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            Task {
                await Task.yield()
                for window in NSApp.windows where window.isVisible && window.canBecomeKey && window.styleMask.contains(.titled) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
        .keyboardShortcut(",")
    }
}
