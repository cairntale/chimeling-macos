import AppKit

enum MenuBarIcon {
    static func image(for status: MenuBarStatus?) -> NSImage {
        switch status {
        case .signedOut:
            signedOut
        case .error:
            error
        case nil:
            plain
        }
    }

    private static let plain = render(statusColor: nil)
    private static let signedOut = render(statusColor: MenuBarStatus.signedOutColor)
    private static let error = render(statusColor: MenuBarStatus.errorColor)

    private static let side: CGFloat = 16
    private static let diameter: CGFloat = 5
    private static let knockout: CGFloat = 1

    private static var isDebug: Bool {
        ChimelingEnvironment.current == .development
    }

    private enum Corner {
        case top
        case bottom

        func rect(in bounds: NSRect) -> NSRect {
            let y =
                switch self {
                case .top:
                    bounds.maxY - diameter
                case .bottom:
                    bounds.minY
                }
            return NSRect(x: bounds.maxX - diameter, y: y, width: diameter, height: diameter)
        }
    }

    private static func render(statusColor: NSColor?) -> NSImage {
        let base = baseImage()
        let marks = marks(statusColor: statusColor)
        guard !marks.isEmpty else {
            base.isTemplate = true
            return base
        }

        let composed = NSImage(size: base.size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current else { return false }
            NSColor.labelColor.set()
            rect.fill()
            base.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
            for mark in marks {
                stamp(mark.color, at: mark.corner, in: rect, context: context)
            }
            return true
        }
        composed.isTemplate = false
        return composed
    }

    private static func baseImage() -> NSImage {
        let image = (NSImage(named: "MenuBarIcon")?.copy() as? NSImage) ?? NSImage()
        image.size = NSSize(width: side, height: side)
        return image
    }

    private static func marks(statusColor: NSColor?) -> [(color: NSColor, corner: Corner)] {
        var marks: [(color: NSColor, corner: Corner)] = []
        if let statusColor {
            marks.append((statusColor, .top))
        }
        if isDebug {
            marks.append((.systemOrange, marks.isEmpty ? .top : .bottom))
        }
        return marks
    }

    private static func stamp(
        _ color: NSColor,
        at corner: Corner,
        in rect: NSRect,
        context: NSGraphicsContext
    ) {
        let badge = corner.rect(in: rect)
        let knockoutRect = badge.insetBy(dx: -knockout, dy: -knockout)
        context.saveGraphicsState()
        context.compositingOperation = .destinationOut
        NSColor.black.set()
        NSBezierPath(ovalIn: knockoutRect).fill()
        context.restoreGraphicsState()

        color.set()
        NSBezierPath(ovalIn: badge).fill()
    }
}
