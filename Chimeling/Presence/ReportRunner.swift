import Foundation

enum RunError: Error, Equatable, Sendable {
    case auth
    case failed(String)

    var message: String {
        switch self {
        case .auth:
            "Presence authorization failed"
        case .failed(let message):
            message
        }
    }
}

final class ReportRunner {
    private let livePresence: LivePresence
    private let registration: Registration
    private let api: ChimelingAPI
    private var chain: Task<Result<Void, RunError>, Never>?
    private var isSignedIn: () -> Bool

    init(
        livePresence: LivePresence,
        registration: Registration,
        api: ChimelingAPI,
        isSignedIn: @escaping () -> Bool
    ) {
        self.livePresence = livePresence
        self.registration = registration
        self.api = api
        self.isSignedIn = isSignedIn
    }

    func run() async -> Result<Void, RunError> {
        let previous = chain
        let task = Task { @MainActor in
            _ = await previous?.value
            return await runInner()
        }
        chain = task
        return await task.value
    }

    func run(timeout: Duration) async -> Result<Void, RunError> {
        await withTimeout(timeout) { await self.run() }
    }

    func clear() async -> Result<Void, RunError> {
        let previous = chain
        let task = Task { @MainActor in
            _ = await previous?.value
            return await clearInner()
        }
        chain = task
        return await task.value
    }

    func clear(timeout: Duration) async -> Result<Void, RunError> {
        await withTimeout(timeout) { await self.clear() }
    }

    private func withTimeout(
        _ timeout: Duration,
        _ operation: @escaping () async -> Result<Void, RunError>
    ) async -> Result<Void, RunError> {
        await withTaskGroup(of: Result<Void, RunError>.self) { group in
            group.addTask { @MainActor in
                await operation()
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return .failure(.failed("report runner timed out"))
            }
            let first = await group.next() ?? .failure(.failed("report runner timed out"))
            group.cancelAll()
            return first
        }
    }

    private func runInner() async -> Result<Void, RunError> {
        do {
            try await runThrowing()
            return .success(())
        } catch let error as RunError {
            return .failure(error)
        } catch let error as RegistrationError {
            return .failure(classify(error))
        } catch {
            return .failure(.failed(error.localizedDescription))
        }
    }

    private func runThrowing() async throws {
        guard isSignedIn() else { return }

        var presence = livePresence.current
        let clearing = presence.status == .offline

        if !clearing {
            _ = try await registration.ensureDeviceID()
        }

        var outcome = try await registration.run(for: presence)
        var loops = 0
        while !outcome.alreadySatisfied {
            loops += 1
            if loops > PresenceTiming.readyLoopCap {
                throw RunError.failed("registration did not become ready")
            }
            presence = livePresence.current
            outcome = try await registration.run(for: presence)
        }

        let report = PresenceFilter.filter(presence, appID: outcome.appID)
        let delete = report.status == .offline
        let deviceID = try registration.cachedDeviceID()

        if delete {
            guard let deviceID, !deviceID.isEmpty else { return }
            let result = try await api.clearPresence(deviceID: deviceID)
            try await interpret(result, identifier: presence.activity?.identifier, deleting: true)
            return
        }

        guard let deviceID, !deviceID.isEmpty else {
            throw RunError.failed("device id is missing")
        }
        guard report.status != .offline else {
            throw RunError.failed("offline is not a reportable status")
        }
        let result = try await api.reportPresence(
            deviceID: deviceID,
            status: report.status,
            activity: report.activity
        )
        try await interpret(result, identifier: presence.activity?.identifier, deleting: false)
    }

    private func clearInner() async -> Result<Void, RunError> {
        do {
            try await clearThrowing()
            return .success(())
        } catch let error as RunError {
            return .failure(error)
        } catch let error as RegistrationError {
            return .failure(classify(error))
        } catch {
            return .failure(.failed(error.localizedDescription))
        }
    }

    private func clearThrowing() async throws {
        let deviceID = try registration.cachedDeviceID()
        guard let deviceID, !deviceID.isEmpty else { return }
        let result = try await api.clearPresence(deviceID: deviceID)
        try await interpret(result, identifier: nil, deleting: true)
    }

    private func interpret(
        _ outcome: APIOutcome<Void>,
        identifier: String?,
        deleting: Bool
    ) async throws {
        switch outcome {
        case .success:
            return
        case .unauthorized:
            throw RunError.auth
        case .notFound:
            if deleting {
                return
            }
            try? await registration.invalidateDevice()
            throw RunError.failed("device 404")
        case .unprocessable:
            if !deleting, let identifier {
                try? registration.invalidateApp(identifier: identifier)
            }
            throw RunError.failed("presence 422")
        case .conflict:
            throw RunError.failed("presence 409")
        case .failure(let status):
            if deleting {
                throw RunError.failed("clear presence failed: \(status)")
            }
            throw RunError.failed("report presence failed: \(status)")
        }
    }

    private func classify(_ error: RegistrationError) -> RunError {
        switch error {
        case .unauthorized:
            .auth
        default:
            .failed(error.localizedDescription)
        }
    }
}
