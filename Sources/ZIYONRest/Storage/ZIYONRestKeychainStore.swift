// ZIYONRestKeychainStore.swift
// ZIYON SAS — Swift 6 REST Client

import Foundation
import Security

// MARK: — Keychain store

/// Persists the auth session in the system Keychain.
/// This is the default and recommended store for production apps.
public actor ZIYONRestKeychainStore: ZIYONRestSessionStore {

    private let service: String
    private let account: String

    public init(
        service: String = "fr.ziyon.rest",
        account: String = "auth.session"
    ) {
        self.service = service
        self.account = account
    }

    public func load() async throws -> ZIYONRestAuthSession? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw ZIYONRestError.unknown("Keychain read error: \(status)")
        }

        guard let data = result as? Data else { return nil }
        do {
            return try JSONDecoder().decode(ZIYONRestAuthSession.self, from: data)
        } catch {
            throw ZIYONRestError.decodingFailed(error)
        }
    }

    public func save(_ session: ZIYONRestAuthSession) async throws {
        let data = try JSONEncoder().encode(session)

        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemDelete(attributes as CFDictionary)
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ZIYONRestError.unknown("Keychain write error: \(status)")
        }
    }

    public func clear() async throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ZIYONRestError.unknown("Keychain delete error: \(status)")
        }
    }
}
