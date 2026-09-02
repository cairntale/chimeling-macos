import Foundation

final class ReportTimer {
    private let livePresence: LivePresence
    private let runner: ReportRunner
    private(set) var signedIn = false
    private var inFlight = false
    private var dirty = false
    private var debounceTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var retryDelay = PresenceTiming.retryStart
    private var last: Presence?
    var onFinished: ((Result<Void, RunError>) -> Void)?

    init(livePresence: LivePresence, runner: ReportRunner) {
        self.livePresence = livePresence
        self.runner = runner
    }

    func setSignedIn(_ signedIn: Bool) {
        self.signedIn = signedIn
        cancelDebounce()
        if signedIn {
            bell()
        } else {
            cancelRetry()
            cancelHeartbeat()
        }
    }

    func onPresence(_ presence: Presence) {
        let previous = last ?? .empty
        last = presence

        let statusChanged = previous.status != presence.status
        let debounceChanged = debounceFields(previous) != debounceFields(presence)

        if statusChanged {
            cancelDebounce()
            if signedIn {
                bell()
            }
        }

        if debounceChanged, presence.status != .offline {
            scheduleDebounce()
        }
    }

    func bell() {
        dirty = true
        resetHeartbeat()
        pump()
    }

    private func scheduleDebounce() {
        guard signedIn else { return }
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: PresenceTiming.activityDebounce)
            guard !Task.isCancelled else { return }
            self?.bell()
        }
    }

    private func cancelDebounce() {
        debounceTask?.cancel()
        debounceTask = nil
    }

    private func cancelHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    private func cancelRetry() {
        retryTask?.cancel()
        retryTask = nil
    }

    private func resetHeartbeat() {
        cancelHeartbeat()
        guard signedIn, livePresence.current.status != .offline else { return }
        heartbeatTask = Task { [weak self] in
            try? await Task.sleep(for: PresenceTiming.heartbeat)
            guard !Task.isCancelled else { return }
            self?.bell()
        }
    }

    private func scheduleRetry() {
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, PresenceTiming.retryCap)
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.bell()
        }
    }

    private func pump() {
        guard !inFlight else { return }
        inFlight = true
        Task { [weak self] in
            await self?.pumpLoop()
        }
    }

    private func pumpLoop() async {
        while true {
            dirty = false
            let result = await runner.run()
            switch result {
            case .success:
                retryDelay = PresenceTiming.retryStart
                cancelRetry()
            case .failure:
                scheduleRetry()
                onFinished?(result)
                breakLoop()
                return
            }
            onFinished?(result)
            if !dirty { break }
        }
        breakLoop()
        if dirty {
            pump()
        }
    }

    private func breakLoop() {
        inFlight = false
    }

    private func debounceFields(_ presence: Presence) -> (String?, String?) {
        if let activity = presence.activity {
            (activity.identifier, activity.name)
        } else {
            (nil, nil)
        }
    }
}

private func min(_ lhs: Duration, _ rhs: Duration) -> Duration {
    lhs < rhs ? lhs : rhs
}
