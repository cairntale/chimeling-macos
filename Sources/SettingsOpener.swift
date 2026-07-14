import SwiftUI
import AppKit
import Combine

@MainActor
@Observable
final class SettingsOpener {
    private(set) var isSettingsOpen = false
    private var isOpening = false
    private var openSettingsAction: (() -> Void)?
    private var openObserver: AnyCancellable?
    private var closeObserver: AnyCancellable?

    init() {
        openObserver = NotificationCenter.default
            .publisher(for: NSWindow.didBecomeMainNotification)
            .compactMap { $0.object as? NSWindow }
            .filter { $0.isSwiftUISettingsWindow }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isSettingsOpen = true
            }

        closeObserver = NotificationCenter.default
            .publisher(for: NSWindow.willCloseNotification)
            .compactMap { $0.object as? NSWindow }
            .filter { $0.isSwiftUISettingsWindow }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.settingsDidClose()
            }
    }

    func register(openSettings: @escaping () -> Void) {
        self.openSettingsAction = openSettings
    }

    func requestOpen() {
        guard !isSettingsOpen, !isOpening else {
            NSWindow.swiftUISettingsWindow?.orderFrontRegardless()
            return
        }
        isOpening = true

        Task { @MainActor in
            defer { isOpening = false }
            NSApp.setActivationPolicy(.regular)
            try? await Task.sleep(nanoseconds: Self.activationPolicyDelayNanoseconds)
            NSApp.activate(ignoringOtherApps: true)
            openSettingsAction?()
            try? await Task.sleep(nanoseconds: Self.windowOrderingDelayNanoseconds)
            NSWindow.swiftUISettingsWindow?.orderFrontRegardless()
        }
    }

    private func settingsDidClose() {
        NSApp.setActivationPolicy(.accessory)
        isSettingsOpen = false
    }

    private static let activationPolicyDelayNanoseconds: UInt64 = 100_000_000
    private static let windowOrderingDelayNanoseconds: UInt64 = 200_000_000
}

extension NSWindow {
    static let swiftUISettingsIdentifier = "com.apple.SwiftUI.Settings"

    var isSwiftUISettingsWindow: Bool {
        identifier?.rawValue == Self.swiftUISettingsIdentifier
    }

    static var swiftUISettingsWindow: NSWindow? {
        NSApp.windows.first { $0.isSwiftUISettingsWindow }
    }
}
