// ZIYONRestStorageAlternatives.swift
// ZIYON SAS - Swift 6 REST Client

import Foundation

// MARK: - UserDefaults store

/// Persists the auth session in `UserDefaults`.
/// Suitable for non-sensitive data, demos, or development builds.
public actor ZIYONRestDefaultsStore: ZIYONRestSessionStore {

    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "ziyon.rest.session"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func load() async throws -> ZIYONRestAuthSession? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(ZIYONRestAuthSession.self, from: data)
        } catch {
            throw ZIYONRestError.decodingFailed(error)
        }
    }

    public func save(_ session: ZIYONRestAuthSession) async throws {
        do {
            let data = try JSONEncoder().encode(session)
            defaults.set(data, forKey: key)
        } catch {
            throw ZIYONRestError.encodingFailed(error)
        }
    }

    public func clear() async throws {
        defaults.removeObject(forKey: key)
    }
}

// MARK: - Memory store

/// Stores the session in memory. Lost on app termination.
/// Best for tests, SwiftUI previews, and ephemeral flows.
public actor ZIYONRestMemoryStore: ZIYONRestSessionStore {

    private var session: ZIYONRestAuthSession?

    public init(session: ZIYONRestAuthSession? = nil) {
        self.session = session
    }

    public func load() async throws -> ZIYONRestAuthSession? { session }

    public func save(_ session: ZIYONRestAuthSession) async throws {
        self.session = session
    }

    public func clear() async throws { session = nil }
}

// MARK: - Null store

/// A no-op store that never persists anything.
/// Use when you handle token storage yourself or in stateless environments.
public actor ZIYONRestNullStore: ZIYONRestSessionStore {
    public init() {}
    public func load() async throws -> ZIYONRestAuthSession? { nil }
    public func save(_ session: ZIYONRestAuthSession) async throws {}
    public func clear() async throws {}
}
