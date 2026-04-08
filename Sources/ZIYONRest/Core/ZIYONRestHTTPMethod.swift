// ZIYONRestHTTPMethod.swift
// ZIYON SAS — Swift 6 REST Client

import Foundation

/// Standard HTTP methods supported by ZIYONRest.
public enum ZIYONRestHTTPMethod: String, Sendable {
    case get     = "GET"
    case post    = "POST"
    case put     = "PUT"
    case patch   = "PATCH"
    case delete  = "DELETE"
    case head    = "HEAD"
    case options = "OPTIONS"
}
