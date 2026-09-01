import Foundation

enum ChimelingEnvironment {
    case development
    case production

    static var current: Self {
        #if DEBUG
        .development
        #else
        .production
        #endif
    }

    var clerkPublishableKey: String {
        switch self {
        case .development:
            "pk_test_cmlnaHQtcm9kZW50LTE2LmNsZXJrLmFjY291bnRzLmRldiQ"
        case .production:
            "pk_live_Y2xlcmsuY2hpbWVsaW5nLmFwcCQ"
        }
    }

    var serverURL: URL {
        switch self {
        case .development:
            URL(string: "http://localhost:3000")!
        case .production:
            URL(string: "https://chimeling.app")!
        }
    }
}
