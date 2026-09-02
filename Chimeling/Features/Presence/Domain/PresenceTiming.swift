import Foundation

nonisolated enum PresenceTiming {
    static let activityDebounce: Duration = .seconds(5)
    static let heartbeat: Duration = .seconds(5 * 60)
    static let retryStart: Duration = .seconds(1)
    static let retryCap: Duration = .seconds(60)
    static let offlineTimeout: Duration = .seconds(2)
    static let iconTTL: TimeInterval = 7 * 24 * 60 * 60
    static let iconTarget = 256
    static let readyLoopCap = 8
}
