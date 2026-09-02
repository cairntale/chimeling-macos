import AppKit

enum MenuStatusDot {
    static let blue = image(color: .systemBlue)
    static let red = image(color: .systemRed)

    private static func image(color: NSColor) -> NSImage {
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
