import ClerkKit
import Combine
import Sparkle
import SwiftUI

struct MenuBarContent: View {
    @Bindable var service: PresenceService
    let updater: SPUUpdater
    @Environment(Clerk.self) private var clerk
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if let status = MenuBarStatus(
            isLoaded: clerk.isLoaded,
            isSignedIn: clerk.session != nil,
            lastError: service.lastError
        ) {
            switch status {
            case .signedOut:
                Button(action: signIn) {
                    Label {
                        Text("Sign in…")
                    } icon: {
                        Image(nsImage: MenuStatusDot.image(for: status))
                    }
                }
                .labelStyle(.titleAndIcon)
            case .error(let error):
                Button {
                    PresenceErrorAlert.present(message: error.message)
                } label: {
                    Label {
                        Text("An error occurred")
                    } icon: {
                        Image(nsImage: MenuStatusDot.image(for: status))
                    }
                }
                .labelStyle(.titleAndIcon)
            }
            Divider()
        }

        FocusedAppMenuRow(service: service)

        Divider()

        OpenSettingsButton()

        CheckForUpdatesView(updater: updater)

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

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}
