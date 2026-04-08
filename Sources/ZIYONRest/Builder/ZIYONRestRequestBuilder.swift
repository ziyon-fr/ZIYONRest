// ZIYONRestRequestBuilder.swift
// ZIYON SAS - Swift 6 REST Client

import Foundation

// MARK: - Request builder

/// A fluent, value-type builder that accumulates request components and
/// dispatches the final HTTP call when a terminal method is called.
///
/// Instances are returned by ``ZIYONRestClient/path(_:)`` and
/// ``ZIYONRestAuthClient/path(_:)``.
public struct ZIYONRestRequestBuilder: Sendable {

    var context: ZIYONRestRequestContext
    let executor: ZIYONRestExecutor
    let authToken: String?      // injected by auth client; nil for plain client

    // MARK: - Path

    /// Appends a path segment.
    public func path(_ segment: some ZIYONRestPathSegment) -> ZIYONRestRequestBuilder {
        var copy = self
        copy.context.pathSegments.append(segment.pathString)
        return copy
    }

    /// Appends multiple path segments at once.
    public func paths(_ segments: any ZIYONRestPathSegment...) -> ZIYONRestRequestBuilder {
        var copy = self
        copy.context.pathSegments.append(contentsOf: segments.map(\.pathString))
        return copy
    }

    /// Appends the path component of the given URL.
    public func path(url: URL) -> ZIYONRestRequestBuilder {
        var copy = self
        copy.context.baseURL = copy.context.baseURL.appendingPathComponent(url.path)
        return copy
    }

    // MARK: - Query

    /// Adds query parameters by encoding an `Encodable` model.
    public func query<T: Encodable & Sendable>(_ model: T) throws -> ZIYONRestRequestBuilder {
        var copy = self
        let data = try context.config.jsonCoding.encoder.encode(model)
        if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (key, value) in dict {
                copy.context.queryItems.append(URLQueryItem(name: key, value: "\(value)"))
            }
        }
        return copy
    }

    /// Adds a single key-value query parameter.
    public func parameter(_ key: String, _ value: String) -> ZIYONRestRequestBuilder {
        var copy = self
        copy.context.queryItems.append(URLQueryItem(name: key, value: value))
        return copy
    }

    /// Adds multiple key-value query parameters.
    public func parameters(_ params: [String: String]) -> ZIYONRestRequestBuilder {
        var copy = self
        for (k, v) in params { copy.context.queryItems.append(URLQueryItem(name: k, value: v)) }
        return copy
    }

    // MARK: - Headers

    /// Adds a single request header.
    public func header(_ key: String, _ value: String) -> ZIYONRestRequestBuilder {
        var copy = self
        copy.context.headers[key] = value
        return copy
    }

    /// Adds multiple request headers.
    public func headers(_ dict: [String: String]) -> ZIYONRestRequestBuilder {
        var copy = self
        for (k, v) in dict { copy.context.headers[k] = v }
        return copy
    }

    // MARK: - Auth override

    /// Skips attaching the bearer token for this one request (e.g. login endpoint).
    public func noAuth() -> ZIYONRestRequestBuilder {
        var copy = self
        copy.context.skipAuth = true
        return copy
    }

    // MARK: - Timeout override

    /// Overrides the timeout for this single request.
    public func timeout(_ seconds: TimeInterval) -> ZIYONRestRequestBuilder {
        var copy = self
        copy.context.timeoutInterval = seconds
        return copy
    }

    // MARK: - HTTP verb setters (return ZIYONRestPendingRequest)

    /// Configures a GET request.
    public func get() -> ZIYONRestPendingRequest {
        var copy = self
        copy.context.method = .get
        return ZIYONRestPendingRequest(builder: copy)
    }

    /// Configures a POST request with an optional body.
    public func post<T: Encodable & Sendable>(body: T) throws -> ZIYONRestPendingRequest {
        var copy = self
        copy.context.method = .post
        copy.context.body = try executor.encode(body)
        return ZIYONRestPendingRequest(builder: copy)
    }

    /// Configures a POST request with no body.
    public func post() -> ZIYONRestPendingRequest {
        var copy = self
        copy.context.method = .post
        return ZIYONRestPendingRequest(builder: copy)
    }

    /// Configures a PUT request with a body.
    public func put<T: Encodable & Sendable>(body: T) throws -> ZIYONRestPendingRequest {
        var copy = self
        copy.context.method = .put
        copy.context.body = try executor.encode(body)
        return ZIYONRestPendingRequest(builder: copy)
    }

    /// Configures a PATCH request with a body.
    public func patch<T: Encodable & Sendable>(body: T) throws -> ZIYONRestPendingRequest {
        var copy = self
        copy.context.method = .patch
        copy.context.body = try executor.encode(body)
        return ZIYONRestPendingRequest(builder: copy)
    }

    /// Configures a DELETE request.
    public func delete() -> ZIYONRestPendingRequest {
        var copy = self
        copy.context.method = .delete
        return ZIYONRestPendingRequest(builder: copy)
    }

    /// Configures a HEAD request.
    public func head() -> ZIYONRestPendingRequest {
        var copy = self
        copy.context.method = .head
        return ZIYONRestPendingRequest(builder: copy)
    }

    /// Configures an OPTIONS request.
    public func options() -> ZIYONRestPendingRequest {
        var copy = self
        copy.context.method = .options
        return ZIYONRestPendingRequest(builder: copy)
    }
}

// MARK: - Pending request (terminal methods)

/// Returned by every HTTP-verb method. Call one terminal method to fire the request.
public struct ZIYONRestPendingRequest: Sendable {

    let builder: ZIYONRestRequestBuilder

    // MARK: Terminal: typed value

    /// Fires the request and returns the decoded value.
    public func value<T: Decodable & Sendable>() async throws -> T {
        let (data, response) = try await fire()
        let validated = try builder.executor.validate(data: data, response: response)
        return try builder.executor.decode(T.self, from: validated)
    }

    /// Fires the request and returns the decoded value plus all response headers.
    public func valueAndHeaders<T: Decodable & Sendable>() async throws -> (T, [String: String]) {
        let (data, response) = try await fire()
        let validated = try builder.executor.validate(data: data, response: response)
        let decoded: T = try builder.executor.decode(T.self, from: validated)
        let headers = lowercasedHeaders(response)
        return (decoded, headers)
    }

    // MARK: Terminal: typed response envelope

    /// Fires the request and returns a ``ZIYONRestResponse`` containing status, headers, and data.
    public func response<T: Decodable & Sendable>() async throws -> ZIYONRestResponse<T> {
        let (data, http) = try await fire()
        let headers = lowercasedHeaders(http)
        if (200..<300).contains(http.statusCode), !data.isEmpty {
            let decoded: T = try builder.executor.decode(T.self, from: data)
            return ZIYONRestResponse(statusCode: http.statusCode, headers: headers, data: decoded)
        }
        return ZIYONRestResponse(statusCode: http.statusCode, headers: headers, data: nil)
    }

    // MARK: Terminal: raw

    /// Fires the request and returns the raw status, headers, and body without throwing on HTTP errors.
    public func raw() async throws -> ZIYONRestRawResponse {
        let (data, http) = try await fire()
        return ZIYONRestRawResponse(httpResponse: http, data: data)
    }

    // MARK: Terminal: send (fire and forget success/failure)

    /// Fires the request and throws only on network errors. HTTP 2xx is required.
    public func send() async throws {
        let (data, response) = try await fire()
        _ = try builder.executor.validate(data: data, response: response)
    }

    // MARK: Internal fire

    private func fire() async throws -> (Data, HTTPURLResponse) {
        let request = try builder.context.buildRequest(authToken: builder.authToken)
        return try await builder.executor.execute(request)
    }

    private func lowercasedHeaders(_ response: HTTPURLResponse) -> [String: String] {
        var result: [String: String] = [:]
        for (k, v) in response.allHeaderFields {
            if let key = k as? String, let val = v as? String {
                result[key.lowercased()] = val
            }
        }
        return result
    }
}
