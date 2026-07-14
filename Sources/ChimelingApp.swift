import SwiftUI
import AppKit

@main
struct ChimelingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("ChimelingKeepalive", id: "hidden") {
            HiddenSettingsWindowView()
        }
        .defaultSize(width: 1, height: 1)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .environment(appDelegate.settingsOpener)

        Settings {
            SettingsView()
                .environment(appDelegate.settingsOpener)
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
        guard let window = NSApp.windows.first(where: { $0.title == "ChimelingKeepalive" }) else { return }

        window.styleMask = [.borderless]
        window.collectionBehavior = [.auxiliary, .ignoresCycle, .transient]
        window.isExcludedFromWindowsMenu = true
        window.level = .floating
        window.isOpaque = false
        window.alphaValue = 0
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.canHide = false
        window.setContentSize(NSSize(width: 1, height: 1))
        window.setFrameOrigin(NSPoint(x: -5000, y: -5000))
        window.isMovable = false
    }
}
