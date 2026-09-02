import SwiftUI

enum AvatarImageCache {
    static let images: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.countLimit = 50
        return cache
    }()
}

struct CachedAvatar: View {
    let url: URL?
    let size: CGFloat

    @State private var image: NSImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let displayed = image ?? cachedImage() {
                Image(nsImage: displayed)
                    .resizable()
                    .scaledToFill()
            } else if didFail || url == nil {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .task(id: url) {
            await load()
        }
    }

    private func cachedImage() -> NSImage? {
        guard let url else {
            return nil
        }
        return AvatarImageCache.images.object(forKey: url as NSURL)
    }

    private func load() async {
        didFail = false
        guard let url else {
            image = nil
            return
        }
        if let cached = AvatarImageCache.images.object(forKey: url as NSURL) {
            image = cached
            return
        }
        image = nil
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let loaded = NSImage(data: data) else {
                didFail = true
                return
            }
            AvatarImageCache.images.setObject(loaded, forKey: url as NSURL)
            image = loaded
        } catch {
            didFail = true
        }
    }
}
