import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let presenceService = PresenceService()
    let settingsNavigation = SettingsNavigation()

    func applicationDidFinishLaunching(_ notification: Notification) {
        OpenSettings.navigation = settingsNavigation
        presenceService.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        presenceService.beginTermination {
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
