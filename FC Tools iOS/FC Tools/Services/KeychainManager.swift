import Foundation
import Security

struct KeychainManager {
    private let service = "com.fctools.app.ea-login"

    func save(email: String, password: String) throws {
        let payload = try JSONEncoder().encode(Credentials(email: email, password: password))
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "ea"
        ]
        SecItemDelete(baseQuery as CFDictionary)
        var item = baseQuery
        item[kSecValueData as String] = payload
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status) }
    }

    func read() -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "ea",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Credentials.self, from: data)
    }

    func delete() { SecItemDelete([
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: "ea"
    ] as CFDictionary) }

    struct Credentials: Codable { let email: String; let password: String }
    struct KeychainError: LocalizedError {
        let status: OSStatus
        init(_ status: OSStatus) { self.status = status }
        var errorDescription: String? { "Could not save secure login (Keychain error (status))." }
    }
}
