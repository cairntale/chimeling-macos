import Foundation

enum AboutCopyright {
    static let startYear = 2026
    static let holder = "Cairntale LLC"
    static let reservedLine = "All rights reserved."

    static func years(now: Int = Calendar.current.component(.year, from: .now)) -> String {
        if now <= startYear {
            return "\(startYear)"
        }
        return "\(startYear)–\(now)"
    }

    static func noticeLine(now: Int = Calendar.current.component(.year, from: .now)) -> String {
        "© \(years(now: now)) \(holder)."
    }
}
