import ClerkKit
import SwiftUI

struct AccountIdentityView: View {
    let user: User
    let avatarSize: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CachedAvatar(url: URL(string: user.imageUrl), size: avatarSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(AccountUserFormatting.displayName(for: user))
                    .font(.headline)
                if let email = AccountUserFormatting.secondaryEmail(for: user) {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AccountUserFormatting.accessibilityLabel(for: user))
    }
}
