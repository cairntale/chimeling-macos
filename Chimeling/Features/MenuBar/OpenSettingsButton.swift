import SwiftUI

struct OpenSettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // SettingsLink does not activate an LSUIElement app, so the window stays behind.
        Button("Settings…", action: open)
            .keyboardShortcut(",")
            .labelStyle(.titleOnly)
    }

    private func open() {
        OpenSettings.activate(openSettings)
    }
}
