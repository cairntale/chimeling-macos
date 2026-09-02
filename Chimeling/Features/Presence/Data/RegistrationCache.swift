import Foundation
import SwiftData

final class RegistrationCache {
    static let version = 1
    static let platform = "darwin"

    private let container: ModelContainer
    private(set) var isInMemoryFallback = false

    private var context: ModelContext {
        container.mainContext
    }

    init() {
        let schema = Schema([DeviceRecord.self, RegisteredApp.self, KnownIcon.self])
        let url = URL.applicationSupportDirectory.appending(path: "registration.store")
        do {
            container = try Self.open(schema: schema, url: url)
        } catch {
            Self.deleteStore(at: url)
            do {
                container = try Self.open(schema: schema, url: url)
            } catch {
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do {
                    container = try ModelContainer(for: schema, configurations: [configuration])
                    isInMemoryFallback = true
                } catch {
                    fatalError("Unable to create registration cache: \(error)")
                }
            }
        }
        context.autosaveEnabled = false
    }

    func load(deviceID: String) throws {
        if let device = try fetchDevice(), cacheMatches(device, deviceID: deviceID) {
            return
        }
        try discardAndCreateEmpty(deviceID: deviceID)
    }

    func reset(deviceID: String) throws {
        let name = try fetchDevice()?.name ?? ""
        try discardAndCreateEmpty(deviceID: deviceID, name: name)
    }

    func cachedDevice() throws -> CachedDevice? {
        try fetchDevice().map {
            CachedDevice(id: $0.id, platform: $0.platform, name: $0.name)
        }
    }

    func setDeviceName(_ name: String) throws {
        guard let device = try fetchDevice(), device.name != name else { return }
        device.name = name
        try context.save()
    }

    func findApp(identifier: String) throws -> CachedApp? {
        try fetchApp(identifier: identifier).map {
            CachedApp(
                identifier: $0.identifier,
                appID: $0.chimelingAppID,
                name: $0.name,
                iconHash: $0.iconHash
            )
        }
    }

    func hasIcon(_ hash: String) throws -> Bool {
        try fetchIcon(hash: hash) != nil
    }

    func appsEmpty() throws -> Bool {
        try context.fetchCount(FetchDescriptor<RegisteredApp>()) == 0
    }

    func upsert(_ app: CachedApp) throws {
        if let existing = try fetchApp(identifier: app.identifier) {
            existing.chimelingAppID = app.appID
            existing.name = app.name
            existing.iconHash = app.iconHash
        } else {
            context.insert(
                RegisteredApp(
                    identifier: app.identifier,
                    chimelingAppID: app.appID,
                    name: app.name,
                    iconHash: app.iconHash
                )
            )
        }
        try context.save()
    }

    func dropApp(identifier: String) throws {
        guard let app = try fetchApp(identifier: identifier) else { return }
        context.delete(app)
        try context.save()
    }

    func addIcon(_ hash: String) throws {
        if try hasIcon(hash) { return }
        context.insert(KnownIcon(iconHash: hash))
        try context.save()
    }

    func dropIcon(_ hash: String) throws {
        guard let icon = try fetchIcon(hash: hash) else { return }
        context.delete(icon)
        try context.save()
    }

    func replace(apps: [CachedApp], iconHashes: [String]) throws {
        try wipeAppsAndIcons()
        for app in apps {
            context.insert(
                RegisteredApp(
                    identifier: app.identifier,
                    chimelingAppID: app.appID,
                    name: app.name,
                    iconHash: app.iconHash
                )
            )
        }
        var seen = Set<String>()
        for hash in iconHashes where seen.insert(hash).inserted {
            context.insert(KnownIcon(iconHash: hash))
        }
        try context.save()
    }

    private func cacheMatches(_ device: DeviceRecord, deviceID: String) -> Bool {
        device.version == Self.version
            && device.platform == Self.platform
            && device.id == deviceID
    }

    private func discardAndCreateEmpty(deviceID: String, name: String = "") throws {
        try wipeAll()
        context.insert(
            DeviceRecord(
                id: deviceID,
                platform: Self.platform,
                name: name,
                version: Self.version
            )
        )
        try context.save()
    }

    private func fetchDevice() throws -> DeviceRecord? {
        var descriptor = FetchDescriptor<DeviceRecord>()
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchApp(identifier: String) throws -> RegisteredApp? {
        let identifier = identifier
        var descriptor = FetchDescriptor<RegisteredApp>(
            predicate: #Predicate { $0.identifier == identifier }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchIcon(hash: String) throws -> KnownIcon? {
        let iconHash = hash
        var descriptor = FetchDescriptor<KnownIcon>(
            predicate: #Predicate { $0.iconHash == iconHash }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func wipeAll() throws {
        try context.delete(model: RegisteredApp.self)
        try context.delete(model: KnownIcon.self)
        try context.delete(model: DeviceRecord.self)
    }

    private func wipeAppsAndIcons() throws {
        try context.delete(model: RegisteredApp.self)
        try context.delete(model: KnownIcon.self)
    }

    private static func open(schema: Schema, url: URL) throws -> ModelContainer {
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let configuration = ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func deleteStore(at url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            try? fm.removeItem(atPath: url.path + suffix)
        }
    }
}
