import Foundation

struct RegistrationOutcome: Sendable {
    var alreadySatisfied: Bool
    var appID: String?
}

enum RegistrationError: Error, LocalizedError {
    case unauthorized
    case deviceNotFound
    case iconUnprocessable
    case iconMissing
    case cacheUnavailable
    case keychain(OSStatus)
    case requestFailed(operation: String, status: Int)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Presence authorization failed"
        case .deviceNotFound:
            "Device not found"
        case .iconUnprocessable:
            "Icon was not accepted"
        case .iconMissing:
            "Icon is missing for app registration"
        case .cacheUnavailable:
            "Registration cache is not loaded"
        case .keychain(let status):
            "Keychain failed: \(status)"
        case .requestFailed(let operation, let status):
            "\(operation) failed: \(status)"
        case .transport(let message):
            message
        }
    }
}

final class Registration {
    private let api: ChimelingAPI
    private let cache: RegistrationCache
    private let icons: AppIconProvider
    private var repairedDeviceID: String?
    private var nameSynced = false

    init(api: ChimelingAPI, cache: RegistrationCache, icons: AppIconProvider) {
        self.api = api
        self.cache = cache
        self.icons = icons
    }

    func cachedDeviceID() throws -> String? {
        try keychain { try DeviceIdentity.load() }
    }

    func ensureDeviceID() async throws -> String {
        if let id = try cachedDeviceID(), !id.isEmpty {
            try cache.load(deviceID: id)
            return id
        }

        let name = DeviceName.current
        let outcome = try await api.registerDevice(name: name)
        switch outcome {
        case .success(let device):
            try keychain { try DeviceIdentity.save(device.id) }
            try cache.load(deviceID: device.id)
            try cache.setDeviceName(name)
            return device.id
        case .unauthorized:
            throw RegistrationError.unauthorized
        case .notFound, .conflict, .unprocessable, .failure:
            throw RegistrationError.requestFailed(operation: "registerDevice", status: outcome.status ?? 0)
        }
    }

    func syncDeviceName() async throws {
        guard !nameSynced else { return }
        let deviceID = try await ensureDeviceID()
        let name = DeviceName.current
        if try cache.cachedDevice()?.name == name {
            nameSynced = true
            return
        }
        let outcome = try await api.updateDevice(id: deviceID, name: name)
        switch outcome {
        case .success:
            try cache.setDeviceName(name)
            nameSynced = true
        case .notFound:
            try await invalidateDevice()
            nameSynced = true
        case .unauthorized:
            throw RegistrationError.unauthorized
        case .conflict, .unprocessable, .failure:
            throw RegistrationError.requestFailed(operation: "updateDevice", status: outcome.status ?? 0)
        }
    }

    func run(for presence: Presence) async throws -> RegistrationOutcome {
        guard let activity = presence.activity else {
            return RegistrationOutcome(alreadySatisfied: true, appID: nil)
        }
        return try await run(activity: activity)
    }

    func invalidateDevice() async throws {
        try keychain { try DeviceIdentity.delete() }
        nameSynced = false
        let deviceID = try await ensureDeviceID()
        try cache.reset(deviceID: deviceID)
        repairedDeviceID = deviceID
    }

    func invalidateApp(identifier: String) throws {
        try cache.dropApp(identifier: identifier)
    }

    private func run(activity: FocusedActivity) async throws -> RegistrationOutcome {
        var didWork = false
        try await ensureLoaded(&didWork)

        let png = icons.png(for: activity.identifier)
        let iconHash = png.map(SHA256Hex.hash)

        if let hash = iconHash, let png {
            didWork = try await ensureIcon(hash: hash, png: png) || didWork
        }

        let existing = try cache.findApp(identifier: activity.identifier)
        if let existing {
            let hashKnown = if let iconHash { try cache.hasIcon(iconHash) } else { true }
            let iconOK = iconHash == existing.iconHash && (iconHash == nil || hashKnown)
            if existing.name == activity.name, iconOK {
                return RegistrationOutcome(alreadySatisfied: !didWork, appID: existing.appID)
            }
        }

        guard let deviceID = try cache.cachedDevice()?.id else {
            throw RegistrationError.cacheUnavailable
        }
        let row: CachedApp
        if let existing {
            row = try await patchApp(deviceID: deviceID, existing: existing, activity: activity, iconHash: iconHash)
        } else {
            row = try await registerApp(deviceID: deviceID, activity: activity, iconHash: iconHash)
        }
        return RegistrationOutcome(alreadySatisfied: false, appID: row.appID)
    }

    private func ensureLoaded(_ didWork: inout Bool) async throws {
        let deviceID = try await ensureDeviceID()
        try cache.load(deviceID: deviceID)

        let checkEmpty: Bool
        if repairedDeviceID != deviceID {
            repairedDeviceID = deviceID
            checkEmpty = true
        } else {
            checkEmpty = false
        }
        if checkEmpty, try cache.appsEmpty() {
            didWork = true
            try await hydrate(deviceID: deviceID)
        }
    }

    private func hydrate(deviceID: String) async throws {
        let outcome = try await api.listApps(deviceID: deviceID)
        switch outcome {
        case .success(let apps):
            let cached = apps.map {
                CachedApp(
                    identifier: $0.identifier,
                    appID: $0.id,
                    name: $0.name,
                    iconHash: $0.iconHash
                )
            }
            let icons = cached.compactMap(\.iconHash)
            try cache.replace(apps: cached, iconHashes: icons)
        case .notFound:
            try await invalidateDevice()
        case .unauthorized:
            throw RegistrationError.unauthorized
        case .conflict, .unprocessable, .failure:
            throw RegistrationError.requestFailed(operation: "listApps", status: outcome.status ?? 0)
        }
    }

    private func ensureIcon(hash: String, png: Data) async throws -> Bool {
        if try cache.hasIcon(hash) {
            return false
        }

        let head = try await api.checkIconExistence(hash: hash)
        switch head {
        case .success:
            try cache.addIcon(hash)
            return true
        case .notFound:
            break
        case .unauthorized:
            throw RegistrationError.unauthorized
        case .conflict, .unprocessable, .failure:
            throw RegistrationError.requestFailed(operation: "checkIconExistence", status: head.status ?? 0)
        }

        try cache.dropIcon(hash)

        let posted = try await api.registerIcon(png: png)
        switch posted {
        case .success, .conflict:
            try cache.addIcon(hash)
            return true
        case .unprocessable:
            try cache.dropIcon(hash)
            throw RegistrationError.iconUnprocessable
        case .unauthorized:
            throw RegistrationError.unauthorized
        case .notFound, .failure:
            throw RegistrationError.requestFailed(operation: "registerIcon", status: posted.status ?? 0)
        }
    }

    private func registerApp(
        deviceID: String,
        activity: FocusedActivity,
        iconHash: String?
    ) async throws -> CachedApp {
        let outcome = try await api.registerApp(
            deviceID: deviceID,
            identifier: activity.identifier,
            name: activity.name,
            iconHash: iconHash
        )
        switch outcome {
        case .success(let app):
            let row = CachedApp(
                identifier: activity.identifier,
                appID: app.id,
                name: activity.name,
                iconHash: iconHash
            )
            try cache.upsert(row)
            return row
        case .notFound:
            try await invalidateDevice()
            throw RegistrationError.deviceNotFound
        case .unprocessable:
            if let iconHash {
                try cache.dropIcon(iconHash)
            }
            throw RegistrationError.iconMissing
        case .unauthorized:
            throw RegistrationError.unauthorized
        case .conflict, .failure:
            throw RegistrationError.requestFailed(operation: "registerApp", status: outcome.status ?? 0)
        }
    }

    private func patchApp(
        deviceID: String,
        existing: CachedApp,
        activity: FocusedActivity,
        iconHash: String?
    ) async throws -> CachedApp {
        let outcome = try await api.updateApp(
            deviceID: deviceID,
            appID: existing.appID,
            name: activity.name,
            iconHash: iconHash
        )
        switch outcome {
        case .success:
            let row = CachedApp(
                identifier: activity.identifier,
                appID: existing.appID,
                name: activity.name,
                iconHash: iconHash
            )
            try cache.upsert(row)
            return row
        case .notFound:
            try cache.dropApp(identifier: activity.identifier)
            return try await registerApp(deviceID: deviceID, activity: activity, iconHash: iconHash)
        case .unprocessable:
            if let iconHash {
                try cache.dropIcon(iconHash)
            }
            throw RegistrationError.iconMissing
        case .unauthorized:
            throw RegistrationError.unauthorized
        case .conflict, .failure:
            throw RegistrationError.requestFailed(operation: "updateApp", status: outcome.status ?? 0)
        }
    }

    private func keychain<T>(_ operation: () throws -> T) throws -> T {
        do {
            return try operation()
        } catch let failure as DeviceIdentity.Failure {
            throw RegistrationError.keychain(failure.status)
        }
    }
}

extension APIOutcome {
    fileprivate var status: Int? {
        switch self {
        case .failure(let status):
            status
        case .unauthorized:
            401
        case .notFound:
            404
        case .conflict:
            409
        case .unprocessable:
            422
        case .success:
            nil
        }
    }
}

enum DeviceName {
    static var current: String {
        let name = Host.current().localizedName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty {
            return name
        }
        return "Unknown"
    }
}
