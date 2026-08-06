import AppKit
import SwiftUI

@MainActor
@Observable
final class FocusedApplicationTracker {
  private(set) var currentApp: FocusedApp?

  init() {
    updateCurrentApp(NSWorkspace.shared.frontmostApplication)

    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(handleActivation(_:)),
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil,
    )
  }

  deinit {
    NSWorkspace.shared.notificationCenter.removeObserver(self)
  }

  @objc private func handleActivation(_ notification: Notification) {
    guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
      return
    }
    updateCurrentApp(app)
  }

  private func updateCurrentApp(_ application: NSRunningApplication?) {
    currentApp = application.map(FocusedApp.init)
  }
}

struct FocusedApp: Equatable {
  let bundleIdentifier: String
  let name: String
  let icon: NSImage?

  init(application: NSRunningApplication) {
    bundleIdentifier = application.bundleIdentifier ?? "Unknown"
    name = application.localizedName ?? "Unknown"
    icon = application.icon
  }

  static func == (lhs: FocusedApp, rhs: FocusedApp) -> Bool {
    lhs.bundleIdentifier == rhs.bundleIdentifier && lhs.name == rhs.name
  }
}
