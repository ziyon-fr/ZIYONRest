// ZIYONRestAsyncHelpers.swift
// ZIYON SAS - Swift 6 REST Client

import Foundation

// MARK: - Data size formatting

extension Int64 {
    /// Returns a human-readable byte count string, e.g. "2.4 MB".
    var formattedByteCount: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

// MARK: - URL convenience

extension URL {
    /// Appends a path segment only when `segment` is non-empty.
    func appendingIfNonEmpty(_ segment: String) -> URL {
        segment.isEmpty ? self : appendingPathComponent(segment)
    }
}
