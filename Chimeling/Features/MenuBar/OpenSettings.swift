import AppKit
import SwiftUI

@MainActor
enum OpenSettings {
    static weak var navigation: SettingsNavigation?

    static func activate(_ openSettings: OpenSettingsAction, tab: SettingsTab? = nil) {
        if let tab {
            navigation?.tab = tab
        }
        NSApp.activate()
        openSettings()
    }
}
