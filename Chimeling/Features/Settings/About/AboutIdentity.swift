import Foundation

struct AboutIdentity {
    static let website = URL(string: "https://chimeling.app")!

    var displayName: String
    var shortVersion: String
    var build: String

    var versionLine: String {
        "Version \(shortVersion) (\(build))"
    }

    var pasteboardString: String {
        "\(displayName) \(shortVersion) (\(build))"
    }

    static var current: Self {
        let bundle = Bundle.main
        return Self(
            displayName: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? "Chimeling",
            shortVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        )
    }
}
