// ZIYONRestConfig.swift
// ZIYON SAS — Swift 6 REST Client

import Foundation

// MARK: — Configuration

/// Immutable configuration passed to both the plain and auth clients.
public struct ZIYONRestConfig: Sendable {

    // MARK: Properties

    /// Default headers added to every request.
    public var baseHeaders: [String: String]

    /// Timeout interval in seconds. Default: 30.
    public var timeoutInterval: TimeInterval

    /// Retry policy. Default: `.standard`.
    public var retryPolicy: ZIYONRestRetryPolicy

    /// Logging level. Default: `.none`.
    public var logging: ZIYONRestLogging

    /// JSON coding behaviour.
    public var jsonCoding: ZIYONRestJSONCoding

    // MARK: Init

    public init(
        baseHeaders: [String: String] = [:],
        timeoutInterval: TimeInterval = 30,
        retryPolicy: ZIYONRestRetryPolicy = .standard,
        logging: ZIYONRestLogging = .none,
        jsonCoding: ZIYONRestJSONCoding = .default
    ) {
        self.baseHeaders = baseHeaders
        self.timeoutInterval = timeoutInterval
        self.retryPolicy = retryPolicy
        self.logging = logging
        self.jsonCoding = jsonCoding
    }

    // MARK: Presets

    /// The default configuration. JSON uses Foundation defaults, 30 s timeout, standard retry.
    public static let standard = ZIYONRestConfig()

    /// Common web-API preset: snake_case keys + ISO 8601 dates + 30 s timeout.
    public static let webAPI = ZIYONRestConfig(
        jsonCoding: .webAPI
    )

    // MARK: Convenience mutators

    /// Returns a copy of this config with the given JSON coding applied.
    public func jsonCoding(_ coding: ZIYONRestJSONCoding) -> ZIYONRestConfig {
        var copy = self
        copy.jsonCoding = coding
        return copy
    }
}

// MARK: — JSON Coding

/// Bundles encoder + decoder options so the call site stays clean.
public struct ZIYONRestJSONCoding: Sendable {

    public let encoder: JSONEncoder
    public let decoder: JSONDecoder

    public init(encoder: JSONEncoder, decoder: JSONDecoder) {
        self.encoder = encoder
        self.decoder = decoder
    }

    // MARK: Presets

    /// Foundation defaults — no key strategy, no date strategy.
    public static let `default`: ZIYONRestJSONCoding = {
        ZIYONRestJSONCoding(encoder: JSONEncoder(), decoder: JSONDecoder())
    }()

    /// snake_case keys + ISO 8601 dates (most common web-API shape).
    public static let webAPI: ZIYONRestJSONCoding = {
        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        enc.dateEncodingStrategy = .iso8601

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        dec.dateDecodingStrategy = .iso8601
        return ZIYONRestJSONCoding(encoder: enc, decoder: dec)
    }()
    

    /// snake_case keys + ISO 8601 with fractional seconds.
    public static let webAPIFractionalSeconds: ZIYONRestJSONCoding = {
        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        enc.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try c.encode(formatter.string(from: date))
        }

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        dec.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let str = try c.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: str) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid ISO 8601 date: \(str)")
            }
            return date
        }
        return ZIYONRestJSONCoding(encoder: enc, decoder: dec)
    }()

    /// ISO 8601 dates only, default key strategy.
    public static let iso8601: ZIYONRestJSONCoding = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return ZIYONRestJSONCoding(encoder: enc, decoder: dec)
    }()

    /// Unix timestamp in seconds.
    public static let unixSeconds: ZIYONRestJSONCoding = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        return ZIYONRestJSONCoding(encoder: enc, decoder: dec)
    }()

    /// Unix timestamp in milliseconds (JavaScript style).
    public static let unixMilliseconds: ZIYONRestJSONCoding = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .millisecondsSince1970
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .millisecondsSince1970
        return ZIYONRestJSONCoding(encoder: enc, decoder: dec)
    }()
}

