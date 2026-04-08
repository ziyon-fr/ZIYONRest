// ZIYONRestAuthBuilder.swift
// ZIYON SAS — Swift 6 REST Client

import Foundation

// MARK: — Auth builder

/// Fluent builder produced by ``ZIYONRest/auth(baseURL:config:session:)``.
///
/// Chain as many options as you need, then read `.client` to get the fully configured
/// ``ZIYONRestAuthClient``.
///
/// ```swift
/// let auth = ZIYONRest
///     .auth(baseURL: apiURL)
///     .keychain()
///     .tokenField("accessToken")
///     .refreshTokenField("refreshToken")
///     .refresh(endpoint: "v1/auth/refresh")
///     .logging(.basic)
///     .client
/// ```
public struct ZIYONRestAuthBuilder: Sendable {

    var baseURL: URL
    var config: ZIYONRestConfig
    var session: URLSession

    // Token extraction
    var tokenJSONField: String = "accessToken"
    var refreshTokenJSONField: String? = nil
    var tokenHeaderName: String? = nil
    var refreshTokenHeaderName: String? = nil

    // Refresh
    var refreshEndpoint: String? = nil
    var refreshMethod: ZIYONRestHTTPMethod = .post
    var refreshRequestField: String = "refreshToken"
    var refreshTriggerCodes: Set<Int> = [401]
    var refreshExtraHeaders: [String: String] = [:]

    // Storage
    var store: (any ZIYONRestSessionStore)? = nil
    var storagePreset: StoragePreset = .keychain

    // Extra headers for every request
    var extraHeaders: [String: String] = [:]

    struct _SendableUserDefaults: @unchecked Sendable {
        let value: UserDefaults
        init(_ value: UserDefaults) { self.value = value }
    }

    enum StoragePreset: Sendable {
        case keychain
        case defaults(_SendableUserDefaults, key: String)
        case memory(seed: ZIYONRestAuthSession?)
        case none
        case custom
    }

    // MARK: — Storage presets

    /// Stores the session in the system Keychain (default, recommended).
    public func keychain() -> ZIYONRestAuthBuilder {
        var copy = self; copy.storagePreset = .keychain; return copy
    }

    /// Stores the session in `UserDefaults`.
    public func defaults(
        _ ud: UserDefaults = .standard,
        key: String = "ziyon.rest.session"
    ) -> ZIYONRestAuthBuilder {
        var copy = self; copy.storagePreset = .defaults(_SendableUserDefaults(ud), key: key); return copy
    }

    /// Stores the session in memory only (lost on app restart).
    public func memory(session: ZIYONRestAuthSession? = nil) -> ZIYONRestAuthBuilder {
        var copy = self; copy.storagePreset = .memory(seed: session); return copy
    }

    /// Disables session persistence.
    public func none() -> ZIYONRestAuthBuilder {
        var copy = self; copy.storagePreset = .none; return copy
    }

    /// Plugs in a custom ``ZIYONRestSessionStore``.
    public func store(_ store: any ZIYONRestSessionStore) -> ZIYONRestAuthBuilder {
        var copy = self
        copy.store = store
        copy.storagePreset = .custom
        return copy
    }

    // MARK: — Token mapping

    /// The JSON field name that carries the access token. Default: `"accessToken"`.
    public func tokenField(_ field: String) -> ZIYONRestAuthBuilder {
        var copy = self; copy.tokenJSONField = field; return copy
    }

    /// The JSON field name that carries the refresh token.
    public func refreshTokenField(_ field: String) -> ZIYONRestAuthBuilder {
        var copy = self; copy.refreshTokenJSONField = field; return copy
    }

    /// Read the access token from a response header instead of JSON.
    public func tokenHeader(_ header: String) -> ZIYONRestAuthBuilder {
        var copy = self; copy.tokenHeaderName = header; return copy
    }

    /// Read the refresh token from a response header instead of JSON.
    public func refreshTokenHeader(_ header: String) -> ZIYONRestAuthBuilder {
        var copy = self; copy.refreshTokenHeaderName = header; return copy
    }

    // MARK: — Refresh configuration

    /// Configures the silent-refresh endpoint called on a 401 (or custom trigger codes).
    public func refresh(
        endpoint: String,
        method: ZIYONRestHTTPMethod = .post,
        requestRefreshField: String = "refreshToken",
        triggerStatusCodes: Set<Int> = [401],
        headers: [String: String] = [:]
    ) -> ZIYONRestAuthBuilder {
        var copy = self
        copy.refreshEndpoint = endpoint
        copy.refreshMethod = method
        copy.refreshRequestField = requestRefreshField
        copy.refreshTriggerCodes = triggerStatusCodes
        copy.refreshExtraHeaders = headers
        return copy
    }

    // MARK: — Timeout / retry / logging passthroughs

    /// Overrides the default timeout.
    public func timeout(_ seconds: TimeInterval) -> ZIYONRestAuthBuilder {
        var copy = self; copy.config.timeoutInterval = seconds; return copy
    }

    /// Sets the retry policy.
    public func retry(_ policy: ZIYONRestRetryPolicy) -> ZIYONRestAuthBuilder {
        var copy = self; copy.config.retryPolicy = policy; return copy
    }

    /// Sets the logging level.
    public func logging(_ level: ZIYONRestLogging) -> ZIYONRestAuthBuilder {
        var copy = self; copy.config.logging = level; return copy
    }

    /// Adds a default header sent on every authenticated request.
    public func header(_ key: String, _ value: String) -> ZIYONRestAuthBuilder {
        var copy = self; copy.extraHeaders[key] = value; return copy
    }

    /// Adds multiple default headers.
    public func headers(_ dict: [String: String]) -> ZIYONRestAuthBuilder {
        var copy = self
        for (k, v) in dict { copy.extraHeaders[k] = v }
        return copy
    }

    // MARK: — JSON coding passthroughs

    /// Overrides the JSON coding preset.
    public func jsonCoding(_ coding: ZIYONRestJSONCoding) -> ZIYONRestAuthBuilder {
        var copy = self; copy.config = copy.config.jsonCoding(coding); return copy
    }

    // MARK: — Build

    /// Returns the configured ``ZIYONRestAuthClient``.
    public var client: ZIYONRestAuthClient {
        let resolvedStore: any ZIYONRestSessionStore
        switch storagePreset {
        case .keychain:
            resolvedStore = ZIYONRestKeychainStore()
        case .defaults(let ud, let key):
            resolvedStore = ZIYONRestDefaultsStore(defaults: ud.value, key: key)
        case .memory(let seed):
            resolvedStore = ZIYONRestMemoryStore(session: seed)
        case .none:
            resolvedStore = ZIYONRestNullStore()
        case .custom:
            resolvedStore = store ?? ZIYONRestMemoryStore()
        }

        return ZIYONRestAuthClient(builder: self, store: resolvedStore)
    }
}

