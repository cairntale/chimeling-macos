import AppKit

enum MenuBarStatus {
    case signedOut
    case error(RunError)

    static let signedOutColor = NSColor.systemBlue
    static let errorColor = NSColor.systemRed

    var accessibilityLabel: String {
        switch self {
        case .signedOut:
            "Chimeling, not signed in"
        case .error:
            "Chimeling, an error occurred"
        }
    }

    /// Signed-out wins, so a stored presence error stays hidden until the user is signed in.
    /// Before Clerk finishes loading, session is nil even for a cached sign-in, so that is not signed-out yet.
    init?(isLoaded: Bool, isSignedIn: Bool, lastError: RunError?) {
        guard isLoaded else { return nil }
        if !isSignedIn {
            self = .signedOut
        } else if let lastError {
            self = .error(lastError)
        } else {
            return nil
        }
    }
}
