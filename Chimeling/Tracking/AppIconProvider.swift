import AppKit
import Foundation

final class AppIconProvider {
    private struct Entry {
        var png: Data
        var cachedAt: Date
    }

    private var cache: [String: Entry] = [:]

    func png(for identifier: String) -> Data? {
        cache[identifier]?.png
    }

    func nsImage(for identifier: String) -> NSImage? {
        png(for: identifier).flatMap(NSImage.init(data:))
    }

    func capture(identifier: String, from app: NSRunningApplication) -> Data? {
        if let entry = cache[identifier], !isExpired(entry.cachedAt) {
            return entry.png
        }
        guard let png = png(from: app) else { return cache[identifier]?.png }
        cache[identifier] = Entry(png: png, cachedAt: .now)
        return png
    }

    private func isExpired(_ cachedAt: Date) -> Bool {
        Date.now.timeIntervalSince(cachedAt) >= PresenceTiming.iconTTL
    }

    private func png(from app: NSRunningApplication) -> Data? {
        let image = app.icon ?? app.bundleURL.map { NSWorkspace.shared.icon(forFile: $0.path) }
        guard let image else { return nil }
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
