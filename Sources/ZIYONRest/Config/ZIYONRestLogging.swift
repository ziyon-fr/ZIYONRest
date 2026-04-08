// ZIYONRestLogging.swift
// ZIYON SAS — Swift 6 REST Client

import Foundation
import os.log

// MARK: — Logging level

/// Controls how much detail is printed to the unified logging system.
public enum ZIYONRestLogging: Sendable {
    /// No logging (default, production recommended).
    case none
    /// Logs method + URL + status code.
    case basic
    /// Logs method, URL, status code, and all request/response headers.
    case headers
    /// Logs method, URL, status code, headers, and body (truncated to 4 KB).
    case verbose
}

// MARK: — Logger

/// Internal logger. Writes to `com.ziyon.rest` subsystem using `os.Logger`.
enum ZIYONRestLogger {
    private static let logger = Logger(subsystem: "com.ziyon.rest", category: "HTTP")

    static func log(
        level: ZIYONRestLogging,
        request: URLRequest,
        response: HTTPURLResponse?,
        data: Data?,
        error: Error?
    ) {
        guard level != .none else { return }

        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "?"
        let status = response.map { "\($0.statusCode)" } ?? (error != nil ? "ERR" : "?")

        logger.info("→ \(method) \(url) [\(status)]")

        if level == .headers || level == .verbose {
            if let reqHeaders = request.allHTTPHeaderFields, !reqHeaders.isEmpty {
                logger.debug("  Request Headers: \(reqHeaders)")
            }
            if let res = response, !res.allHeaderFields.isEmpty {
                logger.debug("  Response Headers: \(res.allHeaderFields)")
            }
        }

        if level == .verbose {
            if let body = request.httpBody, !body.isEmpty {
                let snippet = String(data: body.prefix(4096), encoding: .utf8) ?? "<binary>"
                logger.debug("  Request Body: \(snippet)")
            }
            if let d = data, !d.isEmpty {
                let snippet = String(data: d.prefix(4096), encoding: .utf8) ?? "<binary>"
                logger.debug("  Response Body: \(snippet)")
            }
        }

        if let err = error {
            logger.error("  Error: \(err)")
        }
    }

    static func logDownload(
        url: URL,
        destination: URL,
        bytesWritten: Int64,
        totalBytes: Int64
    ) {
        let pct = totalBytes > 0 ? Int((Double(bytesWritten) / Double(totalBytes)) * 100) : -1
        let pctStr = pct >= 0 ? "\(pct)%" : "?"
        logger.info("↓ DOWNLOAD \(url.lastPathComponent) \(pctStr) → \(destination.lastPathComponent)")
    }
}
