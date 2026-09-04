import Foundation

nonisolated struct ReportableActivity: Sendable, Equatable {
    var appID: String
    var startedAt: Date
}

nonisolated struct ReportablePresence: Sendable, Equatable {
    var status: PresenceStatus
    var activity: ReportableActivity?
}

enum PresenceFilter {
    nonisolated static func filter(_ presence: Presence, appID: String?) -> ReportablePresence {
        let activity: ReportableActivity? =
            if let live = presence.activity, let appID {
                ReportableActivity(appID: appID, startedAt: live.startedAt)
            } else {
                nil
            }
        return ReportablePresence(status: presence.status, activity: activity)
    }
}
