import ClerkKit
import Sparkle
import SwiftUI

struct MenuBarContent: View {
    @Bindable var service: PresenceService
    let updater: SPUUpdater
    @Environment(Clerk.self) private var clerk
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if clerk.isLoaded {
            if clerk.session == nil {
                Button(action: signIn) {
                    statusLabel("Sign in…", status: .signedOut)
                }
                .labelStyle(.titleAndIcon)
                Divider()
            } else if service.filter.isUnreadable || service.lastError != nil {
                if service.filter.isUnreadable {
                    Button(action: showFilterProblem) {
                        statusLabel("Filter needs attention", status: .filterProblem)
                    }
                    .labelStyle(.titleAndIcon)
                }
                if let error = service.lastError {
                    Button {
                        PresenceErrorAlert.present(message: error.message)
                    } label: {
                        statusLabel("An error occurred", status: .error)
                    }
                    .labelStyle(.titleAndIcon)
                }
                Divider()
            }
        }

        FocusedAppMenuRow(service: service)

        Divider()

        OpenSettingsButton()

        CheckForUpdatesView(updater: updater)

        Button("Quit", action: quit)
            .keyboardShortcut("q")
    }

    private func statusLabel(_ title: LocalizedStringKey, status: MenuBarStatus) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(nsImage: MenuStatusDot.image(for: status))
        }
    }

    private func showFilterProblem() {
        OpenSettings.activate(openSettings, tab: .filter)
    }

    private func signIn() {
        OpenSettings.activate(openSettings, tab: .general)
    }

    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
