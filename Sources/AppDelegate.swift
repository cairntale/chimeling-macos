import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let settingsOpener = SettingsOpener()
  let focusedAppTracker = FocusedApplicationTracker()
  private let statusMenuController: StatusMenuController

  override init() {
    statusMenuController = StatusMenuController(
      settingsOpener: settingsOpener,
      focusedAppTracker: focusedAppTracker,
    )
    super.init()
  }

  func applicationDidFinishLaunching(_: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }
}
