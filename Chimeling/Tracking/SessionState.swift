import CoreGraphics
import Foundation

enum SessionState {
    static var isActive: Bool {
        guard let raw = CGSessionCopyCurrentDictionary() else {
            return false
        }
        let dictionary = raw as NSDictionary
        guard let value = dictionary[kCGSessionOnConsoleKey] else {
            return true
        }
        return (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? true
    }
}
