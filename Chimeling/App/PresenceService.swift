import AppKit
import ClerkKit
import Foundation
import os

@Observable
final class PresenceService {
    let livePresence: LivePresence
    let icons: AppIconProvider
    private(set) var lastError: RunError?

    @ObservationIgnored private let registration: Registration
    @ObservationIgnored private let tracker: FocusedAppTracker
    @ObservationIgnored private let statusTracker: StatusTracker
    @ObservationIgnored private let runner: ReportRunner
    @ObservationIgnored private let timer: ReportTimer
    @ObservationIgnored private let signedIn: SignInState
    @ObservationIgnored private var sessionTask: Task<Void, Never>?
    @ObservationIgnored private var isTerminating = false
    @ObservationIgnored private var didReplyToTerminate = false
    @ObservationIgnored private var sleepActivity: NSObjectProtocol?

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Chimeling", category: "presence")

    init() {
        let livePresence = LivePresence()
        let icons = AppIconProvider()
        let cache = RegistrationCache()
        let api = ChimelingAPI()
        let registration = Registration(api: api, cache: cache, icons: icons)
        let signedIn = SignInState()
        let runner = ReportRunner(
            livePresence: livePresence,
            registration: registration,
            api: api,
            isSignedIn: { signedIn.value }
        )
        let timer = ReportTimer(livePresence: livePresence, runner: runner)

        self.livePresence = livePresence
        self.icons = icons
        self.registration = registration
        self.signedIn = signedIn
        self.runner = runner
        self.timer = timer
        tracker = FocusedAppTracker(livePresence: livePresence, icons: icons)
        statusTracker = StatusTracker(livePresence: livePresence, onSuspend: {})
        livePresence.onChange = { presence in
            timer.onPresence(presence)
        }
        timer.onFinished = { [weak self] result in
            self?.handle(result)
        }
        statusTracker.onSuspend = { [weak self] in
            self?.startShortDeadlineReport()
        }
    }

    func start() {
        ProcessInfo.processInfo.disableSuddenTermination()
        tracker.start()
        statusTracker.start()
        sessionTask = Task { [weak self] in
            for await sessionID in Observed.values(of: { Clerk.shared.session?.id }) {
                await self?.applySignIn(sessionID != nil)
            }
        }
    }

    func beginTermination(reply: @escaping () -> Void) {
        guard !isTerminating else {
            reply()
            return
        }
        isTerminating = true
        livePresence.setStatus(.offline)
        tracker.clear()

        func replyOnce() {
            guard !didReplyToTerminate else { return }
            didReplyToTerminate = true
            reply()
        }

        guard signedIn.value else {
            replyOnce()
            return
        }

        Task {
            _ = await runner.run(timeout: PresenceTiming.offlineTimeout)
            replyOnce()
        }
        Task {
            try? await Task.sleep(for: PresenceTiming.offlineTimeout)
            replyOnce()
        }
    }

    func signOut() async {
        let result = await runner.clear(timeout: PresenceTiming.offlineTimeout)
        handle(result)
        try? await Clerk.shared.auth.signOut()
    }

    private func applySignIn(_ isSignedIn: Bool) async {
        signedIn.value = isSignedIn
        if !isSignedIn {
            lastError = nil
        }
        if isSignedIn {
            do {
                try await registration.syncDeviceName()
            } catch {
                Self.log.warning("device name sync failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        timer.setSignedIn(isSignedIn)
    }

    private func startShortDeadlineReport() {
        guard signedIn.value else { return }
        if sleepActivity == nil {
            sleepActivity = ProcessInfo.processInfo.beginActivity(
                options: [.idleSystemSleepDisabled, .userInitiated],
                reason: "Reporting Chimeling offline"
            )
        }
        Task { [weak self] in
            guard let self else { return }
            _ = await runner.run(timeout: PresenceTiming.offlineTimeout)
            if let activity = sleepActivity {
                ProcessInfo.processInfo.endActivity(activity)
                sleepActivity = nil
            }
        }
    }

    private func handle(_ result: Result<Void, RunError>) {
        switch result {
        case .success:
            lastError = nil
        case .failure(let error):
            lastError = error
            if case .auth = error {
                signedIn.value = false
            }
            Self.log.warning("presence report failed: \(error.message, privacy: .public)")
        }
    }
}

final class SignInState {
    var value = false
}
