import ClerkKit
import SwiftUI

struct MenuBarContent: View {
    @Bindable var service: PresenceService
    @Environment(Clerk.self) private var clerk
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if clerk.session == nil {
            Button(action: signIn) {
                Label {
                    Text("Sign in…")
                } icon: {
                    Image(nsImage: MenuStatusDot.blue)
                }
            }
            Divider()
        } else if case .failed(let message) = service.lastError {
            Button(action: {}) {
                Label {
                    Text(message)
                } icon: {
                    Image(nsImage: MenuStatusDot.red)
                }
            }
            .disabled(true)
            Divider()
        }

        FocusedAppMenuRow(service: service)

        Divider()

        OpenSettingsButton()

        Button("Quit", action: quit)
            .keyboardShortcut("q")
    }

    private func signIn() {
        OpenSettings.activate(openSettings, tab: .general)
    }

    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
