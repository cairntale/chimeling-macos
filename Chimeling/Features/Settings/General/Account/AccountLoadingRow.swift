import SwiftUI

struct AccountLoadingRow: View {
    let avatarSize: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .frame(width: avatarSize, height: avatarSize)
                .accessibilityHidden(true)

            Text("Loading account")
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Loading account")

            Spacer(minLength: 8)
        }
    }
}
