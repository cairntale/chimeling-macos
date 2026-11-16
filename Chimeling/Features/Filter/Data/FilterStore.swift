import Foundation
import Observation
import os

@Observable
final class FilterStore {
    private(set) var whitelist = false
    private(set) var identifiers: [String] = []
    private(set) var isUnreadable = false
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private let defaults: UserDefaults

    private static let key = "filter"
    /// First stored shape of this filter. The predicate settings that existed while it was in development are not a version of this.
    private static let version = 1
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Chimeling", category: "filter")

    private struct Storage: Codable {
        var version: Int
        var whitelist: Bool
        var identifiers: [String]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    /// An empty list is not a special case: nothing is listed, so a blacklist excludes nothing and a whitelist excludes everything.
    func excludes(_ identifier: String) -> Bool {
        let listed = identifiers.contains(identifier)
        return whitelist ? !listed : listed
    }

    func setWhitelist(_ enabled: Bool) {
        guard !isUnreadable, whitelist != enabled else { return }
        whitelist = enabled
        persist()
    }

    func add(_ incoming: [String]) {
        guard !isUnreadable else { return }
        var changed = false
        for raw in incoming {
            let identifier = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !identifier.isEmpty, !identifiers.contains(identifier) else { continue }
            identifiers.append(identifier)
            changed = true
        }
        if changed { persist() }
    }

    func remove(_ removing: Set<String>) {
        guard !isUnreadable, !removing.isEmpty else { return }
        let before = identifiers.count
        identifiers.removeAll { removing.contains($0) }
        if identifiers.count != before { persist() }
    }

    func reset() {
        defaults.removeObject(forKey: Self.key)
        whitelist = false
        identifiers = []
        isUnreadable = false
        onChange?()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(
                Storage(version: Self.version, whitelist: whitelist, identifiers: identifiers)
            )
            defaults.set(data, forKey: Self.key)
        } catch {
            Self.log.error("filter storage could not be written")
            isUnreadable = true
        }
        onChange?()
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.key) else { return }
        guard let storage = try? JSONDecoder().decode(Storage.self, from: data),
            storage.version == Self.version
        else {
            Self.log.error("filter storage is unreadable")
            isUnreadable = true
            return
        }
        whitelist = storage.whitelist
        identifiers = storage.identifiers
    }
}
