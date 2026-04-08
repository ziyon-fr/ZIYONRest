//
//  ZIYONServerSentEvent.swift
//  ZIYONRest
//
//  Created by Leon Salvatore on 08.04.2026.
//


/// Represents a standard Server-Sent Event payload.
public struct ZIYONServerSentEvent: Sendable {
    public let event: String?
    public let data: String?
    public let id: String?
    public let retry: Int?
}