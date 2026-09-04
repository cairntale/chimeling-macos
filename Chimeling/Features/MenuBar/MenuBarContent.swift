import ClerkKit
import SwiftUI

struct MenuBarContent: View {
    @Bindable var service: PresenceService
    @Environment(Clerk.self) private var clerk
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let signedOut = clerk.session == nil
        if signedOut {
            Button(action: signIn) {
                Label {
                    Text("Sign in…")
                } icon: {
                    Image(nsImage: MenuStatusDot.blue)
                }
            }
        }
        if let error = service.lastError {
            Button {
                PresenceErrorAlert.present(message: error.message)
            } label: {
                Label {
                    Text("An error occurred")
                } icon: {
                    Image(nsImage: MenuStatusDot.red)
                }
            }
        }
        if signedOut || service.lastError != nil {
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
