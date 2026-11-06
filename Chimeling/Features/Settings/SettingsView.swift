import AppKit
import ClerkKit
import Sparkle
import SwiftUI

struct SettingsView: View {
    @Environment(SettingsNavigation.self) private var navigation
    let updater: SPUUpdater

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.tab) {
            Tab("General", systemImage: "gearshape", value: SettingsTab.general) {
                GeneralSettingsView()
            }
            Tab("Updates", systemImage: "arrow.triangle.2.circlepath", value: SettingsTab.updates) {
                UpdatesSettingsView(updater: updater)
            }
            Tab("About", systemImage: "info.circle", value: SettingsTab.about) {
                AboutSettingsView()
            }
        }
        .frame(width: 500, height: 500)
        .onAppear(perform: activate)
    }

    private func activate() {
        NSApp.activate()
    }
}

#Preview {
    @Previewable @State var controller = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    let _ = Clerk.configure(publishableKey: ChimelingEnvironment.current.clerkPublishableKey)
    SettingsView(updater: controller.updater)
        .environment(Clerk.shared)
        .environment(SettingsNavigation())
        .environment(PresenceService())
}
