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
    private let client: any APIProtocol
    private var chain: Task<Result<Void, RunError>, Never>?
    private var isSignedIn: () -> Bool

    init(
        livePresence: LivePresence,
        registration: Registration,
        client: any APIProtocol,
        isSignedIn: @escaping () -> Bool
    ) {
        self.livePresence = livePresence
        self.registration = registration
        self.client = client
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
        let deviceID = try registration.cachedDeviceID()

        if report.status == .offline {
            guard let deviceID, !deviceID.isEmpty else { return }
            let output = try await client.clearDevicePresence(.init(path: .init(deviceId: deviceID)))
            try await interpretClear(output)
            return
        }

        guard let deviceID, !deviceID.isEmpty else {
            throw RunError.failed("device id is missing")
        }
        let status: Operations.ReportDevicePresence.Input.Body.JsonPayload.StatusPayload =
            switch report.status {
            case .online: .online
            case .idle: .idle
            case .offline:
                throw RunError.failed("offline is not a reportable status")
            }
        let activity = report.activity.map {
            Operations.ReportDevicePresence.Input.Body.JsonPayload.ActivityPayload(
                appId: $0.appID,
                startedAt: $0.startedAt
            )
        }
        let output = try await client.reportDevicePresence(
            .init(
                path: .init(deviceId: deviceID),
                body: .json(.init(status: status, activity: activity))
            )
        )
        try await interpretReport(output, identifier: presence.activity?.identifier)
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
        let output = try await client.clearDevicePresence(.init(path: .init(deviceId: deviceID)))
        try await interpretClear(output)
    }

    private func interpretReport(
        _ output: Operations.ReportDevicePresence.Output,
        identifier: String?
    ) async throws {
        switch output {
        case .noContent:
            return
        case .unauthorized, .forbidden:
            throw RunError.auth
        case .notFound:
            try? await registration.invalidateDevice()
            throw RunError.failed("device 404")
        case .unprocessableContent:
            if let identifier {
                try? registration.invalidateApp(identifier: identifier)
            }
            throw RunError.failed("presence 422")
        case .badRequest:
            throw RunError.failed("report presence failed: 400")
        case .undocumented(let status, _):
            throw RunError.failed("report presence failed: \(status)")
        }
    }

    private func interpretClear(_ output: Operations.ClearDevicePresence.Output) async throws {
        switch output {
        case .noContent, .notFound:
            return
        case .unauthorized, .forbidden:
            throw RunError.auth
        case .badRequest:
            throw RunError.failed("clear presence failed: 400")
        case .undocumented(let status, _):
            throw RunError.failed("clear presence failed: \(status)")
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
