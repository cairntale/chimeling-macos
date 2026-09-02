import Foundation
import SwiftData

@Model
final class DeviceRecord {
    var id: String
    var platform: String
    var name: String
    var version: Int = 0

    init(id: String, platform: String = "darwin", name: String = "", version: Int) {
        self.id = id
        self.platform = platform
        self.name = name
        self.version = version
    }
}

@Model
final class RegisteredApp {
    @Attribute(.unique) var identifier: String
    var chimelingAppID: String
    var name: String
    var iconHash: String?

    init(identifier: String, chimelingAppID: String, name: String, iconHash: String?) {
        self.identifier = identifier
        self.chimelingAppID = chimelingAppID
        self.name = name
        self.iconHash = iconHash
    }
}

@Model
final class KnownIcon {
    @Attribute(.unique) var iconHash: String

    init(iconHash: String) {
        self.iconHash = iconHash
    }
}

nonisolated struct CachedDevice: Sendable, Equatable {
    var id: String
    var platform: String
    var name: String
}

nonisolated struct CachedApp: Sendable, Equatable {
    var identifier: String
    var appID: String
    var name: String
    var iconHash: String?
}
