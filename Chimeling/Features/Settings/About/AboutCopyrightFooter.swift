import SwiftUI

struct AboutCopyrightFooter: View {
    var body: some View {
        VStack(spacing: 2) {
            Text(AboutCopyright.noticeLine())
            Text(AboutCopyright.reservedLine)
        }
        .font(.footnote)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
    }
}
