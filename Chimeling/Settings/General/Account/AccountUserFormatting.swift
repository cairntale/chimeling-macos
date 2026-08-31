import ClerkKit
import Foundation

enum AccountUserFormatting {
    static func displayName(for user: User) -> String {
        var components = PersonNameComponents()
        if let given = trimmed(user.firstName) {
            components.givenName = given
        }
        if let family = trimmed(user.lastName) {
            components.familyName = family
        }
        let formatted = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !formatted.isEmpty {
            return formatted
        }
        if let username = trimmed(user.username) {
            return username
        }
        if let email = user.primaryEmailAddress?.emailAddress, !email.isEmpty {
            return email
        }
        return "Signed in"
    }

    static func secondaryEmail(for user: User) -> String? {
        guard let email = user.primaryEmailAddress?.emailAddress, !email.isEmpty else {
            return nil
        }
        if email == displayName(for: user) {
            return nil
        }
        return email
    }

    static func accessibilityLabel(for user: User) -> String {
        let name = displayName(for: user)
        if let email = secondaryEmail(for: user) {
            return "\(name), \(email)"
        }
        return name
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        return trimmed
    }
}
