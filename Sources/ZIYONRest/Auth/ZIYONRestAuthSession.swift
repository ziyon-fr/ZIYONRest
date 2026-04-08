// ZIYONRestAuthSession.swift
// ZIYON SAS - Swift 6 REST Client

import Foundation

// MARK: - Auth session

/// The persisted session state managed by ``ZIYONRestAuthClient``.
public struct ZIYONRestAuthSession: Codable, Sendable, Equatable {

    /// The primary bearer token (access token).
    public var token: String?

    /// The refresh token, if your API provides one.
    public var refreshToken: String?

    /// Arbitrary metadata your app wants to persist (e.g. user ID, expiry timestamp).
    public var metadata: [String: String]

    public init(
        token: String? = nil,
        refreshToken: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.token = token
        self.refreshToken = refreshToken
        self.metadata = metadata
    }
}

// MARK: - Session store protocol

/// Implement this protocol to plug in a custom session-persistence backend.
public protocol ZIYONRestSessionStore: Actor {
    /// Loads the last saved session, or `nil` if none exists.
    func load() async throws -> ZIYONRestAuthSession?
    /// Persists a session.
    func save(_ session: ZIYONRestAuthSession) async throws
    /// Clears the stored session.
    func clear() async throws
}
