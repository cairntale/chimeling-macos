import Foundation

enum RelativeSince {
    static func string(for date: Date, relativeTo now: Date = .now) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: now)
    }

    static func nextRefresh(from date: Date, now: Date = .now) -> Date {
        let current = string(for: date, relativeTo: now)
        let origin = now.timeIntervalSinceReferenceDate
        let cap = origin + 60 * 60 * 24 * 370

        func text(_ instant: TimeInterval) -> String {
            string(for: date, relativeTo: Date(timeIntervalSinceReferenceDate: instant))
        }

        var offset: TimeInterval = 1
        while origin + offset < cap, text(origin + offset) == current {
            offset *= 2
        }

        if origin + offset >= cap {
            return Date(timeIntervalSinceReferenceDate: cap)
        }

        var low = origin + offset / 2
        var high = origin + offset
        while high - low > 0.25 {
            let mid = (low + high) / 2
            if text(mid) == current {
                low = mid
            } else {
                high = mid
            }
        }

        return Date(timeIntervalSinceReferenceDate: high)
    }
}
