import Foundation
import OpenAPIRuntime

nonisolated struct ISO8601: DateTranscoder {
    private let fractional = ISO8601DateTranscoder(options: [.withInternetDateTime, .withFractionalSeconds])
    private let whole = ISO8601DateTranscoder()

    func encode(_ date: Date) throws -> String {
        try fractional.encode(date)
    }

    func decode(_ dateString: String) throws -> Date {
        if let date = try? fractional.decode(dateString) {
            return date
        }
        return try whole.decode(dateString)
    }
}
