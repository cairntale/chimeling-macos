import AppKit

enum MenuBarStatus {
    case signedOut
    case error
    case filterProblem

    static let signedOutColor = NSColor.systemBlue
    static let errorColor = NSColor.systemRed

    var accessibilityLabel: String {
        switch self {
        case .signedOut:
            "Chimeling, not signed in"
        case .error:
            "Chimeling, an error occurred"
        case .filterProblem:
            "Chimeling, the filter needs attention"
        }
    }

    /// Signed-out wins, so a stored presence error stays hidden until the user is signed in.
    /// Before Clerk finishes loading, session is nil even for a cached sign-in, so that is not signed-out yet.
    /// This is the single state the icon shows; the menu lists a filter problem and an error separately.
    init?(isLoaded: Bool, isSignedIn: Bool, hasFilterProblem: Bool, lastError: RunError?) {
        guard isLoaded else { return nil }
        if !isSignedIn {
            self = .signedOut
        } else if hasFilterProblem {
            self = .filterProblem
        } else if lastError != nil {
            self = .error
        } else {
            return nil
        }
    }
}
