nonisolated enum IconChoice: Equatable, Sendable {
    case exact(Int)
    case downscale(Int)
    case asIs(Int)
}

enum IconRepresentation {
    nonisolated static func choose(sizes: [(width: Int, height: Int)], target: Int = PresenceTiming.iconTarget) -> IconChoice? {
        for (index, size) in sizes.enumerated() {
            if size.width == target, size.height == target {
                return .exact(index)
            }
        }

        var bestDownscale: (area: Int, index: Int)?
        var bestAsIs: (longest: Int, index: Int)?
        for (index, size) in sizes.enumerated() {
            guard size.width > 0, size.height > 0 else { continue }
            if size.width >= target, size.height >= target {
                let area = size.width * size.height
                if bestDownscale.map({ area < $0.area }) ?? true {
                    bestDownscale = (area, index)
                }
            }
            let longest = max(size.width, size.height)
            if bestAsIs.map({ longest > $0.longest }) ?? true {
                bestAsIs = (longest, index)
            }
        }

        if let bestDownscale {
            return .downscale(bestDownscale.index)
        }
        if let bestAsIs {
            return .asIs(bestAsIs.index)
        }
        return nil
    }
}
