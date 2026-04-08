//
//  ISO8601FractionalFormatterCache.swift
//  ZIYONRest
//
//  Created by Leon Salvatore on 08.04.2026.
//

import Foundation

actor ISO8601FractionalFormatterCache {
    static let shared = ISO8601FractionalFormatterCache()
    private let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    func string(from date: Date) -> String { formatter.string(from: date) }
    func date(from string: String) -> Date? { formatter.date(from: string) }
}
