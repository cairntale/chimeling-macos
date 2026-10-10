import ClerkKit
import SwiftUI

struct MenuBarIconLabel: View {
    let service: PresenceService
    @Environment(Clerk.self) private var clerk

    var body: some View {
        let status = MenuBarStatus(
            isLoaded: clerk.isLoaded,
            isSignedIn: clerk.session != nil,
            lastError: service.lastError
        )
        Image(nsImage: MenuBarIcon.image(for: status))
            .accessibilityLabel(status?.accessibilityLabel ?? "Chimeling")
    }
}
