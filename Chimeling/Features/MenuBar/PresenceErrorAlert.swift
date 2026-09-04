import AppKit

@MainActor
enum PresenceErrorAlert {
    static func present(message: String) {
        NSApp.activate()
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.icon = Bundle.main.image(forResource: "AppIcon")
            ?? NSImage(named: "AppIcon")
        alert.messageText = "Presence reporting failed"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Copy")
        alert.accessoryView = accessory(message)
        alert.layout()
        if alert.runModal() == .alertSecondButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message, forType: .string)
        }
    }

    private static func accessory(_ message: String) -> NSView {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 360, height: 140))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .bezelBorder
        scroll.autoresizingMask = [.width]

        let text = NSTextView(frame: scroll.contentView.bounds)
        text.minSize = NSSize(width: 0, height: 0)
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.textContainer?.containerSize = NSSize(
            width: scroll.contentSize.width,
            height: .greatestFiniteMagnitude
        )
        text.textContainer?.widthTracksTextView = true
        text.isEditable = false
        text.isSelectable = true
        text.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        text.string = message
        scroll.documentView = text
        return scroll
    }
}
