import AppKit
import SwiftUI

@main
struct ChimelingApp: App {
    var body: some Scene {
        MenuBarExtra("Chimeling", systemImage: "bell") {
            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
        .defaultSize(width: 500, height: 320)
    }
}
