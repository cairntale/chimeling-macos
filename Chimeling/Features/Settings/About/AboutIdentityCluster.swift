import AppKit
import SwiftUI

struct AboutIdentityCluster: View {
    let identity: AboutIdentity

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: ChimelingAppIcon.image)
                .resizable()
                .frame(width: 128, height: 128)
                .padding(.bottom, 8)
                .accessibilityHidden(true)

            Text(identity.displayName)
                .font(.title)
                .bold()

            VStack(spacing: 2) {
                AboutVersionLabel(identity: identity)

                Link("chimeling.app", destination: AboutIdentity.website)
                    .font(.callout)
                    .tint(Color(nsColor: .linkColor))
            }
        }
        .multilineTextAlignment(.center)
    }
}
