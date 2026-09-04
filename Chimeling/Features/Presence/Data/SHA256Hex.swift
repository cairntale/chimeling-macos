import CryptoKit
import Foundation

enum SHA256Hex {
    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).reduce(into: "") { hex, byte in
            hex.append(hexDigit(byte >> 4))
            hex.append(hexDigit(byte & 0x0F))
        }
    }

    private static func hexDigit(_ value: UInt8) -> Character {
        let value = Int(value)
        if value < 10 {
            return Character(UnicodeScalar(48 + value)!)
        } else {
            return Character(UnicodeScalar(87 + value)!)
        }
    }
}
