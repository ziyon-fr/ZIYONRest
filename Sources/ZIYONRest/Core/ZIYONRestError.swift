// ZIYONRestError.swift
// ZIYON SAS - Swift 6 REST Client

import Foundation

// MARK: - Client errors

/// Errors thrown by ``ZIYONRestClient`` and ``ZIYONRestAuthClient``.
public enum ZIYONRestError: Error, Sendable, LocalizedError {

    /// The URL could not be constructed from the given components.
    case invalidURL(String)

    /// The server returned a non-2xx status code.
    case httpError(statusCode: Int, body: Data?)

    /// The response body could not be decoded into the expected type.
    case decodingFailed(Error)

    /// The request body could not be encoded.
    case encodingFailed(Error)

    /// The network layer returned an error.
    case networkError(Error)

    /// The token refresh flow failed.
    case refreshFailed(Error?)

    /// The request was cancelled.
    case cancelled

    /// A download-specific error.
    case downloadError(ZIYONRestDownloadError)

    /// An unexpected condition occurred.
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let u):
            return "Invalid URL: \(u)"
        case .httpError(let code, _):
            return "HTTP \(code)"
        case .decodingFailed(let e):
            return "Decoding failed: \(e.localizedDescription)"
        case .encodingFailed(let e):
            return "Encoding failed: \(e.localizedDescription)"
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        case .refreshFailed(let e):
            return "Token refresh failed: \(e?.localizedDescription ?? "unknown")"
        case .cancelled:
            return "Request cancelled."
        case .downloadError(let e):
            return e.localizedDescription
        case .unknown(let msg):
            return msg
        }
    }
}

// MARK: - Download errors

/// Errors specific to the download subsystem.
public enum ZIYONRestDownloadError: Error, Sendable, LocalizedError {
    /// The downloaded file could not be moved to the destination.
    case moveFileFailed(URL, Error)
    /// The server did not provide a `Content-Length` header.
    case unknownContentLength
    /// The response was not a valid HTTP response.
    case invalidResponse
    /// The download was resumed but the resume data is stale or corrupt.
    case invalidResumeData
    /// The download task is already running.
    case alreadyRunning

    public var localizedDescription: String {
        switch self {
        case .moveFileFailed(let url, let e):
            return "Failed to move downloaded file to \(url.path): \(e)"
        case .unknownContentLength:
            return "Server did not report Content-Length."
        case .invalidResponse:
            return "Response is not a valid HTTP response."
        case .invalidResumeData:
            return "Resume data is stale or corrupt."
        case .alreadyRunning:
            return "A download for this URL is already in progress."
        }
    }
}
