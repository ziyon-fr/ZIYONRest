// ZIYONRestRequestContext.swift
// ZIYON SAS - Swift 6 REST Client

import Foundation

// MARK: - Request context

/// Internal value type that accumulates everything needed to fire one HTTP request.
struct ZIYONRestRequestContext: Sendable {

    var baseURL: URL
    var pathSegments: [String] = []
    var queryItems: [URLQueryItem] = []
    var headers: [String: String] = [:]
    var method: ZIYONRestHTTPMethod = .get
    var body: Data?
    var skipAuth: Bool = false
    var timeoutInterval: TimeInterval
    var config: ZIYONRestConfig

    // MARK: URL construction

    func buildURL() throws -> URL {
        var url = baseURL
        for segment in pathSegments {
            url = url.appendingPathComponent(segment)
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw ZIYONRestError.invalidURL(url.absoluteString)
        }
        if !queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }
        guard let finalURL = components.url else {
            throw ZIYONRestError.invalidURL(url.absoluteString)
        }
        return finalURL
    }

    // MARK: URLRequest construction

    func buildRequest(authToken: String? = nil) throws -> URLRequest {
        let url = try buildURL()
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = method.rawValue

        // Base headers from config
        for (k, v) in config.baseHeaders { request.setValue(v, forHTTPHeaderField: k) }

        // Per-request headers
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }

        // Bearer token
        if let token = authToken, !skipAuth {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Body
        if let body {
            request.httpBody = body
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        // Accept JSON by default
        if request.value(forHTTPHeaderField: "Accept") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }

        return request
    }
}
