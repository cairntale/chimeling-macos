import AppKit
import ClerkKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView()
            }
            Tab("Square", systemImage: "square") {
                SquareSettingsView()
            }
            Tab("Pentagon", systemImage: "pentagon") {
                PentagonSettingsView()
            }
        }
        .frame(width: 500, height: 500)
        .onAppear {
            NSApp.activate()
        }
    }
}

#Preview {
    let _ = Clerk.configure(publishableKey: ClerkPublishableKey.current)
    SettingsView()
        .environment(Clerk.shared)
}
