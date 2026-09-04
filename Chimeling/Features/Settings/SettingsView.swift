import AppKit
import ClerkKit
import SwiftUI

struct SettingsView: View {
    @Environment(SettingsNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.tab) {
            Tab("General", systemImage: "gearshape", value: SettingsTab.general) {
                GeneralSettingsView()
            }
            Tab("Square", systemImage: "square", value: SettingsTab.square) {
                SquareSettingsView()
            }
            Tab("Pentagon", systemImage: "pentagon", value: SettingsTab.pentagon) {
                PentagonSettingsView()
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
    let _ = Clerk.configure(publishableKey: ChimelingEnvironment.current.clerkPublishableKey)
    SettingsView()
        .environment(Clerk.shared)
        .environment(SettingsNavigation())
        .environment(PresenceService())
}
