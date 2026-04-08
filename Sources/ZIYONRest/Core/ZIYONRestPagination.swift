// ZIYONRestPagination.swift
// ZIYON SAS - Swift 6 REST Client

import Foundation

// MARK: - Paginated response

/// A decoded page of items plus optional pagination cursors from response headers or body.
public struct ZIYONRestPage<T: Decodable & Sendable>: Sendable {

    /// The items for this page.
    public let items: [T]

    /// Total number of items across all pages, if the API reports it.
    public let total: Int?

    /// The current page number, if the API reports it.
    public let currentPage: Int?

    /// The total number of pages, if the API reports it.
    public let totalPages: Int?

    /// The next-page cursor or URL, if the API reports it.
    public let nextCursor: String?

    /// `true` when there are more pages to fetch.
    public var hasMore: Bool {
        if let cursor = nextCursor { return !cursor.isEmpty }
        if let cp = currentPage, let tp = totalPages { return cp < tp }
        return false
    }
}

// MARK: - Envelope models

/// A standard envelope that wraps `data` + pagination metadata.
/// Conform your API's page envelope to this shape, or create your own.
public struct ZIYONRestPageEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    public let data: [T]
    public let total: Int?
    public let currentPage: Int?
    public let totalPages: Int?
    public let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case data
        case total
        case currentPage = "current_page"
        case totalPages  = "total_pages"
        case nextCursor  = "next_cursor"
    }
}

// MARK: - PendingRequest extensions

extension ZIYONRestPendingRequest {
    /// Decodes the response into a ``ZIYONRestPage`` using a standard ``ZIYONRestPageEnvelope``.
    public func page<T: Decodable & Sendable>() async throws -> ZIYONRestPage<T> {
        let envelope: ZIYONRestPageEnvelope<T> = try await value()
        return ZIYONRestPage(
            items: envelope.data,
            total: envelope.total,
            currentPage: envelope.currentPage,
            totalPages: envelope.totalPages,
            nextCursor: envelope.nextCursor
        )
    }
}

extension ZIYONRestAuthPendingRequest {
    /// Decodes the response into a ``ZIYONRestPage`` using a standard ``ZIYONRestPageEnvelope``.
    public func page<T: Decodable & Sendable>() async throws -> ZIYONRestPage<T> {
        let envelope: ZIYONRestPageEnvelope<T> = try await value()
        return ZIYONRestPage(
            items: envelope.data,
            total: envelope.total,
            currentPage: envelope.currentPage,
            totalPages: envelope.totalPages,
            nextCursor: envelope.nextCursor
        )
    }
}
