import AppKit
import Foundation

final class StatusTracker {
    private let livePresence: LivePresence
    var onSuspend: () -> Void
    private var observers: [any NSObjectProtocol] = []

    init(livePresence: LivePresence, onSuspend: @escaping () -> Void) {
        self.livePresence = livePresence
        self.onSuspend = onSuspend
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers {
            center.removeObserver(observer)
        }
    }

    func start() {
        applySessionState()
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification) { [weak self] in
            self?.goOffline()
        }
        observe(workspace, NSWorkspace.willPowerOffNotification) { [weak self] in
            self?.goOffline()
        }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { [weak self] in
            self?.goOffline()
        }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { [weak self] in
            self?.goOffline()
        }
        observe(workspace, NSWorkspace.didWakeNotification) { [weak self] in
            self?.resume()
        }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { [weak self] in
            self?.resume()
        }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { [weak self] in
            self?.resume()
        }
    }

    private func goOffline() {
        livePresence.setStatus(.offline)
        onSuspend()
    }

    private func resume() {
        applySessionState()
    }

    private func applySessionState() {
        // TODO: Add idle detection (inactivity polling) so presence can report idle after the user steps away.
        if SessionState.isActive {
            livePresence.setStatus(.online)
        } else {
            livePresence.setStatus(.offline)
        }
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
}
