import Foundation
import Security

enum DeviceIdentity {
    struct Failure: Error {
        var status: OSStatus
    }

    private static let account = "device_id"
    private static var remembered: String?

    static func load() throws -> String? {
        if let remembered {
            return remembered
        }
        let id = try read()
        remembered = id
        return id
    }

    static func save(_ id: String) throws {
        if remembered == id { return }
        if try read() == id {
            remembered = id
            return
        }

        guard let data = id.data(using: .utf8) else {
            throw Failure(status: errSecDecode)
        }

        var query = baseQuery()
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        switch status {
        case errSecSuccess:
            break
        case errSecItemNotFound:
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let added = SecItemAdd(query as CFDictionary, nil)
            guard added == errSecSuccess else {
                throw Failure(status: added)
            }
        default:
            throw Failure(status: status)
        }

        guard try read() == id else {
            throw Failure(status: errSecInternalError)
        }
        remembered = id
    }

    static func delete() throws {
        remembered = nil
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Failure(status: status)
        }
    }

    private static func read() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let id = String(data: data, encoding: .utf8),
                  !id.isEmpty
            else {
                throw Failure(status: errSecDecode)
            }
            return id
        case errSecItemNotFound:
            return nil
        default:
            throw Failure(status: status)
        }
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.cairntale.Chimeling",
            kSecAttrAccount as String: account,
        ]
    }
}
