import AppKit
import Foundation

final class AppIconProvider {
    private var cache: [String: Data] = [:]

    func png(for identifier: String) -> Data? {
        cache[identifier]
    }

    func nsImage(for identifier: String) -> NSImage? {
        png(for: identifier).flatMap(NSImage.init(data:))
    }

    func capture(identifier: String, from app: NSRunningApplication) -> Data? {
        guard let png = png(from: app) else { return cache[identifier] }
        cache[identifier] = png
        return png
    }

    private func png(from app: NSRunningApplication) -> Data? {
        guard let source = app.icon ?? app.bundleURL.map({ NSWorkspace.shared.icon(forFile: $0.path) }) else {
            return nil
        }
        let image = source.copy() as? NSImage ?? source
        let target = PresenceTiming.iconTarget
        image.size = NSSize(width: target, height: target)
        return png(from: image)
    }

    private func png(from image: NSImage) -> Data? {
        let reps = image.representations
        let sizes = reps.map { (width: Int($0.pixelsWide), height: Int($0.pixelsHigh)) }
        switch IconRepresentation.choose(sizes: sizes) {
        case .exact(let index), .asIs(let index):
            return png(from: reps[index])
        case .downscale(let index):
            return rasterize(reps[index], to: PresenceTiming.iconTarget)
        case nil:
            return pngFromTIFF(image)
        }
    }

    private func png(from rep: NSImageRep) -> Data? {
        if let bitmap = rep as? NSBitmapImageRep {
            return bitmap.representation(using: .png, properties: [:])
        }
        let width = max(rep.pixelsWide, 1)
        let height = max(rep.pixelsHigh, 1)
        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(rep)
        return pngFromTIFF(image)
    }

    private func rasterize(_ rep: NSImageRep, to size: Int) -> Data? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        rep.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])
    }

    private func pngFromTIFF(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
