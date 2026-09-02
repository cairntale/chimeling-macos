import ClerkKit
import SwiftUI

struct AccountSignedInRow: View {
    let user: User
    let avatarSize: CGFloat
    let onSignOut: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            AccountIdentityView(user: user, avatarSize: avatarSize)
            Spacer(minLength: 8)
            Button("Sign Out…", action: onSignOut)
                .buttonStyle(.bordered)
                .controlSize(.regular)
        }
    }
}
