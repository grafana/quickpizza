import Foundation
import Security

enum KeychainStorage {
    static func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func write(service: String, account: String, value: String?) {
        if value == nil || value?.isEmpty == true {
            delete(service: service, account: account)
            return
        }
        guard let data = value?.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private enum KeychainServices {
    static let auth = "com.grafana.quickpizza.auth"
    static let debug = "com.grafana.quickpizza.debug"
}

enum AuthKeychain {
    static let tokenAccount = "auth_token"
    static let usernameAccount = "auth_username"

    static func readToken() -> String? {
        KeychainStorage.read(service: KeychainServices.auth, account: tokenAccount)
    }

    static func readUsername() -> String? {
        KeychainStorage.read(service: KeychainServices.auth, account: usernameAccount)
    }

    static func save(token: String, username: String) {
        KeychainStorage.write(service: KeychainServices.auth, account: tokenAccount, value: token)
        KeychainStorage.write(service: KeychainServices.auth, account: usernameAccount, value: username)
    }

    static func clear() {
        KeychainStorage.delete(service: KeychainServices.auth, account: tokenAccount)
        KeychainStorage.delete(service: KeychainServices.auth, account: usernameAccount)
    }
}

enum DebugKeychain {
    static let otlpApiKeyAccount = "debug_otlp_api_key"

    static func readOtlpApiKey() -> String? {
        KeychainStorage.read(service: KeychainServices.debug, account: otlpApiKeyAccount)
    }

    static func writeOtlpApiKey(_ value: String?) {
        KeychainStorage.write(service: KeychainServices.debug, account: otlpApiKeyAccount, value: value)
    }

    static func clearOtlpApiKey() {
        KeychainStorage.delete(service: KeychainServices.debug, account: otlpApiKeyAccount)
    }
}
