import AppKit
import Foundation

final class FocusedAppTracker {
    private let livePresence: LivePresence
    let icons: AppIconProvider
    private var observers: [any NSObjectProtocol] = []
    private var resampleGeneration = 0
    private var currentIdentifier: String?

    init(livePresence: LivePresence, icons: AppIconProvider) {
        self.livePresence = livePresence
        self.icons = icons
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers {
            center.removeObserver(observer)
        }
    }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { [weak self] in
            self?.resampleLater()
        }
        observe(workspace, NSWorkspace.didWakeNotification) { [weak self] in
            self?.resampleLater()
        }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { [weak self] in
            self?.resampleLater()
        }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { [weak self] in
            self?.resampleLater()
        }
        observe(workspace, NSWorkspace.willSleepNotification) { [weak self] in
            self?.clear()
        }
        observe(workspace, NSWorkspace.willPowerOffNotification) { [weak self] in
            self?.clear()
        }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { [weak self] in
            self?.clear()
        }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { [weak self] in
            self?.clear()
        }
        resample()
    }

    func clear() {
        resampleGeneration += 1
        currentIdentifier = nil
        livePresence.setActivity(nil)
    }

    private func resampleLater() {
        resampleGeneration += 1
        let token = resampleGeneration
        Task { @MainActor in
            guard token == resampleGeneration else { return }
            resample()
        }
    }

    private func resample() {
        let workspace = NSWorkspace.shared
        let app = workspace.menuBarOwningApplication ?? workspace.frontmostApplication
        guard let app, let activity = focusedActivity(from: app) else {
            currentIdentifier = nil
            livePresence.setActivity(nil)
            return
        }
        livePresence.setActivity(activity)
        currentIdentifier = activity.identifier
    }

    private func focusedActivity(from app: NSRunningApplication) -> FocusedActivity? {
        guard let identifier = app.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              Self.isUserFacing(identifier)
        else {
            return nil
        }

        let name = app.localizedName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? identifier
        if currentIdentifier != identifier {
            _ = icons.capture(identifier: identifier, from: app)
        }
        let startedAt =
            if currentIdentifier == identifier, let existing = livePresence.current.activity {
                existing.startedAt
            } else {
                Date.now
            }
        return FocusedActivity(name: name, identifier: identifier, startedAt: startedAt)
    }

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        handler: @escaping () -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                handler()
            }
        }
        observers.append(token)
    }

    private static let nonUserFacing: Set<String> = [
        "com.apple.loginwindow",
        "loginwindow",
        "com.apple.ScreenSaver.Engine",
        "com.apple.screensaver",
        "ScreenSaverEngine",
    ]

    private static func isUserFacing(_ identifier: String) -> Bool {
        !identifier.isEmpty
            && !nonUserFacing.contains(where: { $0.caseInsensitiveCompare(identifier) == .orderedSame })
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
