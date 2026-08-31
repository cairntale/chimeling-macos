import AuthenticationServices
import ClerkKit
import SwiftUI

struct AccountSettingsSection: View {
    @Environment(Clerk.self) private var clerk
    @State private var isConfirmingSignOut = false
    @State private var isShowingSignInError = false
    @State private var signInErrorMessage = ""

    private let avatarSize: CGFloat = 36

    var body: some View {
        Section("Account") {
            if !clerk.isLoaded {
                AccountLoadingRow(avatarSize: avatarSize)
            } else if let user = clerk.user {
                AccountSignedInRow(user: user, avatarSize: avatarSize) {
                    isConfirmingSignOut = true
                }
            } else {
                AccountSignedOutRow(avatarSize: avatarSize) {
                    Task {
                        await signIn()
                    }
                }
            }
        }
        .confirmationDialog(
            "Sign Out",
            isPresented: $isConfirmingSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await clerk.auth.signOut()
                }
            }
        } message: {
            Text("You will need to sign in again to use your account.")
        }
        .alert("Unable to Sign In", isPresented: $isShowingSignInError) {
        } message: {
            Text(signInErrorMessage)
        }
    }

    private func signIn() async {
        do {
            try await clerk.auth.startHostedAuth()
        } catch {
            if isUserCancellation(error) {
                return
            }
            signInErrorMessage = error.localizedDescription
            isShowingSignInError = true
        }
    }

    private func isUserCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == ASWebAuthenticationSessionError.errorDomain
            && nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
    }
}
