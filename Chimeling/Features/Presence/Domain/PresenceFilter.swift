import Foundation

nonisolated enum PresenceDecision: Equatable {
    case clear
    case report
}

enum PresenceFilter {
    /// A filtered presence is cleared rather than left to expire, so nothing stale lingers on the server.
    static func decide(_ presence: Presence, filter: FilterStore) -> PresenceDecision {
        if presence.status == .offline || filter.isUnreadable {
            return .clear
        }
        if let activity = presence.activity, filter.excludes(activity.identifier) {
            return .clear
        }
        return .report
    }
}
