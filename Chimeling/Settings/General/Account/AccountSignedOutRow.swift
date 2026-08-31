import SwiftUI

struct AccountSignedOutRow: View {
    let avatarSize: CGFloat
    let onSignIn: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            AccountPlaceholderAvatar(size: avatarSize)

            Text("Not signed in")
                .font(.headline)

            Spacer(minLength: 8)

            Button("Sign In", action: onSignIn)
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
        }
    }
}
