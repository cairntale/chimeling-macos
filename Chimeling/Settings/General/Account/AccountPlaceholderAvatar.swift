import SwiftUI

struct AccountPlaceholderAvatar: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(.secondary)
    }
}
