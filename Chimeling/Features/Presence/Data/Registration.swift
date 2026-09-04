import Foundation
import OpenAPIRuntime

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
    private let client: any APIProtocol
    private let cache: RegistrationCache
    private let icons: AppIconProvider
    private var repairedDeviceID: String?
    private var nameSynced = false

    init(client: any APIProtocol, cache: RegistrationCache, icons: AppIconProvider) {
        self.client = client
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
        let output = try await client.registerDevice(
            .init(body: .json(.init(name: name, platform: .darwin)))
        )
        switch output {
        case .created(let created):
            let device = try created.body.json
            try keychain { try DeviceIdentity.save(device.id) }
            try cache.load(deviceID: device.id)
            try cache.setDeviceName(name)
            return device.id
        case .unauthorized:
            throw RegistrationError.unauthorized
        case .badRequest:
            throw RegistrationError.requestFailed(operation: "registerDevice", status: 400)
        case .undocumented(let status, _):
            throw RegistrationError.requestFailed(operation: "registerDevice", status: status)
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
        let output = try await client.updateDevice(
            .init(path: .init(deviceId: deviceID), body: .json(.init(name: name)))
        )
        switch output {
        case .ok:
            try cache.setDeviceName(name)
            nameSynced = true
        case .notFound:
            try await invalidateDevice()
            nameSynced = true
        case .unauthorized, .forbidden:
            throw RegistrationError.unauthorized
        case .badRequest:
            throw RegistrationError.requestFailed(operation: "updateDevice", status: 400)
        case .undocumented(let status, _):
            throw RegistrationError.requestFailed(operation: "updateDevice", status: status)
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
        let output = try await client.listApps(.init(path: .init(deviceId: deviceID)))
        switch output {
        case .ok(let ok):
            let apps = try ok.body.json
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
        case .unauthorized, .forbidden:
            throw RegistrationError.unauthorized
        case .undocumented(let status, _):
            throw RegistrationError.requestFailed(operation: "listApps", status: status)
        }
    }

    private func ensureIcon(hash: String, png: Data) async throws -> Bool {
        if try cache.hasIcon(hash) {
            return false
        }

        let head = try await client.checkIconExistence(.init(path: .init(hash: hash)))
        switch head {
        case .ok:
            try cache.addIcon(hash)
            return true
        case .notFound:
            break
        case .undocumented(let status, _):
            throw RegistrationError.requestFailed(operation: "checkIconExistence", status: status)
        }

        try cache.dropIcon(hash)

        let posted = try await client.registerIcon(.init(body: .png(HTTPBody(png))))
        switch posted {
        case .created, .conflict:
            try cache.addIcon(hash)
            return true
        case .contentTooLarge, .unsupportedMediaType:
            try cache.dropIcon(hash)
            throw RegistrationError.iconUnprocessable
        case .unauthorized:
            throw RegistrationError.unauthorized
        case .undocumented(let status, _):
            throw RegistrationError.requestFailed(operation: "registerIcon", status: status)
        }
    }

    private func registerApp(
        deviceID: String,
        activity: FocusedActivity,
        iconHash: String?
    ) async throws -> CachedApp {
        let output = try await client.registerApp(
            .init(
                path: .init(deviceId: deviceID),
                body: .json(.init(name: activity.name, identifier: activity.identifier, iconHash: iconHash))
            )
        )
        switch output {
        case .created(let created):
            let app = try created.body.json
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
        case .unprocessableContent:
            if let iconHash {
                try cache.dropIcon(iconHash)
            }
            throw RegistrationError.iconMissing
        case .unauthorized, .forbidden:
            throw RegistrationError.unauthorized
        case .badRequest:
            throw RegistrationError.requestFailed(operation: "registerApp", status: 400)
        case .undocumented(let status, _):
            throw RegistrationError.requestFailed(operation: "registerApp", status: status)
        }
    }

    private func patchApp(
        deviceID: String,
        existing: CachedApp,
        activity: FocusedActivity,
        iconHash: String?
    ) async throws -> CachedApp {
        let output = try await client.updateApp(
            .init(
                path: .init(deviceId: deviceID, appId: existing.appID),
                body: .json(.init(name: activity.name, iconHash: iconHash))
            )
        )
        switch output {
        case .ok:
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
        case .unprocessableContent:
            if let iconHash {
                try cache.dropIcon(iconHash)
            }
            throw RegistrationError.iconMissing
        case .unauthorized, .forbidden:
            throw RegistrationError.unauthorized
        case .badRequest:
            throw RegistrationError.requestFailed(operation: "updateApp", status: 400)
        case .undocumented(let status, _):
            throw RegistrationError.requestFailed(operation: "updateApp", status: status)
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
