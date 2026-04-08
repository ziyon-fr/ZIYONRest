// ZIYONRest.swift
// ZIYON SAS — Swift 6 REST Client
// Copyright © 2025 ZIYON SAS. All rights reserved.

import Foundation

/// Entry point for the ZIYONRest package.
///
/// Use `ZIYONRest.client(baseURL:)` for unauthenticated HTTP requests and
/// `ZIYONRest.auth(baseURL:)` for token-managed sessions with automatic
/// refresh, Keychain storage, and per-request bearer injection.
///
/// ```swift
/// // Plain client
/// let client = ZIYONRest.client(baseURL: apiURL)
///
/// // Auth / session client (Keychain by default)
/// let auth = ZIYONRest.auth(baseURL: apiURL).client
/// ```
public enum ZIYONRest: Sendable {

    // MARK: — Plain client

    /// Creates an unauthenticated HTTP client.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for all requests.
    ///   - config:  Optional configuration. Defaults to `.standard`.
    ///   - session: Optional `URLSession`. Defaults to `.shared`.
    /// - Returns: A ready-to-use ``ZIYONRestClient``.
    public static func client(
        baseURL: URL,
        config: ZIYONRestConfig = .standard,
        session: URLSession = .shared
    ) -> ZIYONRestClient {
        ZIYONRestClient(baseURL: baseURL, config: config, session: session)
    }

    // MARK: — Auth / session client builder

    /// Starts building an authenticated session client.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for all requests.
    ///   - config:  Optional configuration. Defaults to `.standard`.
    ///   - session: Optional `URLSession`. Defaults to `.shared`.
    /// - Returns: A ``ZIYONRestAuthBuilder`` ready to be configured.
    public static func auth(
        baseURL: URL,
        config: ZIYONRestConfig = .standard,
        session: URLSession = .shared
    ) -> ZIYONRestAuthBuilder {
        ZIYONRestAuthBuilder(baseURL: baseURL, config: config, session: session)
    }
}
