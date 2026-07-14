import SwiftUI
import AppKit

struct StatusMenuView: View {
    @Environment(SettingsOpener.self) private var settingsOpener

    var body: some View {
        Button("Settings...") {
            settingsOpener.requestOpen()
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit Chimeling") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

#Preview {
    StatusMenuView()
        .environment(SettingsOpener())
}
