import SwiftUI
import AppKit

@main
struct ChimelingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var settingsOpener = SettingsOpener()

    var body: some Scene {
        // Hidden window required for openSettings() from a menu-bar app.
        Window("", id: "hidden") {
            HiddenSettingsWindowView()
        }
        .defaultSize(width: 1, height: 1)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .environment(settingsOpener)

        MenuBarExtra("Chimeling", systemImage: "bolt.fill") {
            StatusMenuView()
                .environment(settingsOpener)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(settingsOpener)
        }
    }
}

struct HiddenSettingsWindowView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(SettingsOpener.self) private var settingsOpener

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                settingsOpener.register(openSettings: { openSettings() })
                configureHiddenWindow()
            }
    }

    private func configureHiddenWindow() {
        guard let window = NSApp.windows.first(where: { $0.isHiddenWindow }) else { return }
        window.styleMask = [.borderless]
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.isMovable = false
        window.ignoresMouseEvents = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
    }
}

extension NSWindow {
    var isHiddenWindow: Bool {
        frame.size == NSSize(width: 1, height: 1)
    }
}
