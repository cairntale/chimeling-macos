import Foundation

@Observable
final class LivePresence {
    private(set) var current = Presence.empty
    var onChange: ((Presence) -> Void)?

    func setStatus(_ status: PresenceStatus) {
        guard current.status != status else { return }
        current.status = status
        onChange?(current)
    }

    func setActivity(_ activity: FocusedActivity?) {
        guard current.activity != activity else { return }
        current.activity = activity
        onChange?(current)
    }
}
