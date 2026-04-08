// ZIYONRestResponse.swift
// ZIYON SAS — Swift 6 REST Client

import Foundation

// MARK: — Raw response

/// A low-level HTTP response containing status, headers, and raw body bytes.
public struct ZIYONRestRawResponse: Sendable {

    /// HTTP status code.
    public let statusCode: Int

    /// All response headers (lowercased keys).
    public let headers: [String: String]

    /// Raw response body, if any.
    public let rawData: Data?

    /// Attempts to decode the raw body as UTF-8 text.
    public var rawValue: String? {
        rawData.flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Returns the header value for the given key (case-insensitive).
    public func header(_ key: String) -> String? {
        headers[key.lowercased()]
    }

    /// Returns the header value cast to `Int`, if possible.
    public func headerInt(_ key: String) -> Int? {
        header(key).flatMap(Int.init)
    }

    /// Returns `true` when the status code is in the 200–299 range.
    public var isSuccess: Bool { (200..<300).contains(statusCode) }
}

// MARK: — Typed response

/// A typed HTTP response containing status, headers, and a decoded body.
public struct ZIYONRestResponse<T: Sendable>: Sendable {

    /// HTTP status code.
    public let statusCode: Int

    /// All response headers (lowercased keys).
    public let headers: [String: String]

    /// Decoded body, or `nil` when decoding was skipped (e.g. 204 No Content).
    public let data: T?

    /// Returns the header value for the given key (case-insensitive).
    public func header(_ key: String) -> String? {
        headers[key.lowercased()]
    }

    /// Returns the header value cast to `Int`, if possible.
    public func headerInt(_ key: String) -> Int? {
        header(key).flatMap(Int.init)
    }

    /// Returns `true` when the status code is in the 200–299 range.
    public var isSuccess: Bool { (200..<300).contains(statusCode) }
}

// MARK: — Internal helpers

extension ZIYONRestRawResponse {
    init(httpResponse: HTTPURLResponse, data: Data?) {
        self.statusCode = httpResponse.statusCode
        var lowered: [String: String] = [:]
        for (k, v) in httpResponse.allHeaderFields {
            if let key = k as? String, let val = v as? String {
                lowered[key.lowercased()] = val
            }
        }
        self.headers = lowered
        self.rawData = data
    }
}
