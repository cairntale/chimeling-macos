import AppKit

enum MenuStatusDot {
    static func image(for status: MenuBarStatus) -> NSImage {
        switch status {
        case .signedOut:
            signedOut
        case .error:
            error
        }
    }

    private static let signedOut = make(MenuBarStatus.signedOutColor)
    private static let error = make(MenuBarStatus.errorColor)

    private static func make(_ color: NSColor) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 8, weight: .regular)
            .applying(.init(paletteColors: [color]))
        let image =
            NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
            ?? NSImage()
        image.isTemplate = false
        return image
    }
}
