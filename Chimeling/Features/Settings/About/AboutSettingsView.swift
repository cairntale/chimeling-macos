import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        VStack {
            Spacer()
            AboutIdentityCluster(identity: .current)
            Spacer()
            AboutCopyrightFooter()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal)
        .padding(.bottom, 42)
    }
}

#Preview {
    AboutSettingsView()
        .frame(width: 500, height: 500)
}
