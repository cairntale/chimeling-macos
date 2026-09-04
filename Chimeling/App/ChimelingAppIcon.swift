import AppKit

enum ChimelingAppIcon {
    static var image: NSImage {
        NSImage(named: "AppIcon")
            ?? Bundle.main.image(forResource: "AppIcon")
            ?? NSImage()
    }
}
