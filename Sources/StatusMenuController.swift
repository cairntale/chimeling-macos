import AppKit
import SwiftUI

@MainActor
final class StatusMenuController {
    private let settingsOpener: SettingsOpener
    private let focusedAppTracker: FocusedApplicationTracker

    private let statusItem: NSStatusItem
    private let iconImageView: NSImageView
    private let nameTextField: NSTextField
    private let bundleIdTextField: NSTextField

    init(settingsOpener: SettingsOpener, focusedAppTracker: FocusedApplicationTracker) {
        self.settingsOpener = settingsOpener
        self.focusedAppTracker = focusedAppTracker

        statusItem = Self.makeStatusItem()
        iconImageView = Self.makeIconImageView()
        nameTextField = Self.makeNameLabel()
        bundleIdTextField = Self.makeBundleIdLabel()

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(makeFocusedAppItem())
        menu.addItem(.separator())
        menu.addItem(makeSettingsItem())
        menu.addItem(.separator())
        menu.addItem(makeQuitItem())
        statusItem.menu = menu

        updateFocusedApp(focusedAppTracker.currentApp)
        observeFocusedApp()
    }

    private static func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "bolt.fill",
            accessibilityDescription: "Chimeling"
        )
        item.button?.image?.isTemplate = true
        return item
    }

    private func makeFocusedAppItem() -> NSMenuItem {
        let verticalStack = NSStackView(views: [nameTextField, bundleIdTextField])
        verticalStack.orientation = .vertical
        verticalStack.spacing = 2
        verticalStack.alignment = .leading

        let horizontalStack = NSStackView(views: [iconImageView, verticalStack])
        horizontalStack.orientation = .horizontal
        horizontalStack.spacing = 8
        horizontalStack.alignment = .centerY
        horizontalStack.edgeInsets = NSEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)

        let item = NSMenuItem()
        item.isEnabled = false
        item.view = horizontalStack
        return item
    }

    private static func makeIconImageView() -> NSImageView {
        let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 32),
            imageView.heightAnchor.constraint(equalToConstant: 32),
        ])
        return imageView
    }

    private static func makeNameLabel() -> NSTextField {
        let field = makeLabel()
        field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        return field
    }

    private static func makeBundleIdLabel() -> NSTextField {
        let field = makeLabel()
        field.font = NSFont.preferredFont(forTextStyle: .caption1)
        field.textColor = .secondaryLabelColor
        return field
    }

    private static func makeLabel() -> NSTextField {
        let field = NSTextField(labelWithString: "")
        field.isBezeled = false
        field.isEditable = false
        field.drawsBackground = false
        field.lineBreakMode = .byTruncatingTail
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    private func makeSettingsItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        item.keyEquivalentModifierMask = .command
        item.target = self
        return item
    }

    private func makeQuitItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: "Quit Chimeling",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        item.keyEquivalentModifierMask = .command
        item.target = self
        return item
    }

    @objc private func openSettings(_ sender: Any?) {
        settingsOpener.requestOpen()
    }

    @objc private func quit(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }

    private func observeFocusedApp() {
        Observation.withObservationTracking {
            updateFocusedApp(focusedAppTracker.currentApp)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeFocusedApp()
            }
        }
    }

    private func updateFocusedApp(_ app: FocusedApp?) {
        if let app = app {
            iconImageView.image = app.icon
            nameTextField.stringValue = app.name
            bundleIdTextField.stringValue = app.bundleIdentifier
        } else {
            iconImageView.image = nil
            nameTextField.stringValue = "No focused app"
            bundleIdTextField.stringValue = ""
        }
    }
}
