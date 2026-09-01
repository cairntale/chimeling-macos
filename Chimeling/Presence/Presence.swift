import Foundation

nonisolated enum PresenceStatus: String, Sendable, Equatable {
    case online
    case idle
    case offline
}

nonisolated struct FocusedActivity: Sendable, Equatable {
    var name: String
    var identifier: String
    var startedAt: Date
}

nonisolated struct Presence: Sendable, Equatable {
    var status: PresenceStatus
    var activity: FocusedActivity?

    static let empty = Presence(status: .offline, activity: nil)
}
