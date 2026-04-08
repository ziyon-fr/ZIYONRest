// ZIYONRestAuthClient.swift
// ZIYON SAS - Swift 6 REST Client

import Foundation

// MARK: - Auth client

/// An actor-isolated HTTP client that manages bearer tokens, persists sessions,
/// and silently refreshes expired tokens on 401 responses.
///
/// Create via ``ZIYONRestAuthBuilder/client``:
///
/// ```swift
/// let auth = ZIYONRest
///     .auth(baseURL: apiURL)
///     .keychain()
///     .tokenField("accessToken")
///     .refreshTokenField("refreshToken")
///     .refresh(endpoint: "v1/auth/refresh")
///     .client
/// ```
public actor ZIYONRestAuthClient {

    // MARK: Stored properties

    private let builder: ZIYONRestAuthBuilder
    private let store: any ZIYONRestSessionStore
    private let executor: ZIYONRestExecutor

    private var session: ZIYONRestAuthSession?
    private var isRefreshing = false

    // MARK: Init

    init(builder: ZIYONRestAuthBuilder, store: any ZIYONRestSessionStore) {
        self.builder = builder
        self.store = store
        self.executor = ZIYONRestExecutor(session: builder.session, config: builder.config)
    }

    // MARK: - Request chain entry

    /// Starts a request chain. The current access token is automatically injected.
    ///
    /// ```swift
    /// let profile: Profile = try await auth.path("v1/me").get().value()
    /// ```
    public func path(_ segment: some ZIYONRestPathSegment) -> ZIYONRestAuthRequestBuilder {
        var ctx = ZIYONRestRequestContext(
            baseURL: builder.baseURL,
            timeoutInterval: builder.config.timeoutInterval,
            config: builder.config
        )
        ctx.pathSegments.append(segment.pathString)
        ctx.headers.merge(builder.extraHeaders) { _, new in new }
        return ZIYONRestAuthRequestBuilder(context: ctx, client: self)
    }

    /// Starts a request chain using a full URL path.
    public func path(url: URL) -> ZIYONRestAuthRequestBuilder {
        var ctx = ZIYONRestRequestContext(
            baseURL: builder.baseURL.appendingPathComponent(url.path),
            timeoutInterval: builder.config.timeoutInterval,
            config: builder.config
        )
        ctx.headers.merge(builder.extraHeaders) { _, new in new }
        return ZIYONRestAuthRequestBuilder(context: ctx, client: self)
    }

    // MARK: - Session management

    /// Returns the current session, loading it from storage first if needed.
    public func currentSession() async throws -> ZIYONRestAuthSession? {
        if session == nil { session = try await store.load() }
        return session
    }

    /// Persists a token pair and updates the in-memory session.
    public func save(token: String, refreshToken: String? = nil) async throws {
        var s = session ?? ZIYONRestAuthSession()
        s.token = token
        if let rt = refreshToken { s.refreshToken = rt }
        session = s
        try await store.save(s)
    }

    /// Clears the in-memory session and the persisted store.
    public func logout() async throws {
        session = nil
        try await store.clear()
    }

    // MARK: - Internal: fire (used by ZIYONRestAuthRequestBuilder)

    func fire(context: ZIYONRestRequestContext) async throws -> (Data, HTTPURLResponse) {
        // Load session if needed
        if session == nil { session = try await store.load() }
        let token = context.skipAuth ? nil : session?.token

        let request = try context.buildRequest(authToken: token)
        var (data, response) = try await executor.execute(request)

        // Extract + persist token from response if present
        try await extractAndSaveToken(from: response, data: data)

        // Silent refresh on trigger codes
        if builder.refreshTriggerCodes.contains(response.statusCode),
           !context.skipAuth,
           let refreshEp = builder.refreshEndpoint
        {
            guard !isRefreshing else {
                throw ZIYONRestError.refreshFailed(nil)
            }
            isRefreshing = true
            defer { isRefreshing = false }

            do {
                try await performRefresh(endpoint: refreshEp)
            } catch {
                throw ZIYONRestError.refreshFailed(error)
            }

            // Retry original request with new token
            let newToken = session?.token
            let retryRequest = try context.buildRequest(authToken: newToken)
            (data, response) = try await executor.execute(retryRequest)
            try await extractAndSaveToken(from: response, data: data)
        }

        return (data, response)
    }

    // MARK: - Executor forwarding (needed by ZIYONRestAuthRequestBuilder)

    nonisolated func validate(data: Data, response: HTTPURLResponse) throws -> Data {
        guard (200..<300).contains(response.statusCode) else {
            throw ZIYONRestError.httpError(statusCode: response.statusCode, body: data)
        }
        return data
    }

    nonisolated func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try builder.config.jsonCoding.decoder.decode(type, from: data)
        } catch {
            throw ZIYONRestError.decodingFailed(error)
        }
    }

    nonisolated func encode<T: Encodable>(_ body: T) throws -> Data {
        do {
            return try builder.config.jsonCoding.encoder.encode(body)
        } catch {
            throw ZIYONRestError.encodingFailed(error)
        }
    }

    // MARK: - Token extraction

    private func extractAndSaveToken(from response: HTTPURLResponse, data: Data) async throws {
        var updated = session ?? ZIYONRestAuthSession()
        var changed = false

        // Header-based token
        if let headerName = builder.tokenHeaderName {
            let headers = response.allHeaderFields
            let lower = headerName.lowercased()
            for (k, v) in headers {
                if let key = k as? String, key.lowercased() == lower, let val = v as? String {
                    updated.token = val
                    changed = true
                }
            }
        }

        if let headerName = builder.refreshTokenHeaderName {
            let headers = response.allHeaderFields
            let lower = headerName.lowercased()
            for (k, v) in headers {
                if let key = k as? String, key.lowercased() == lower, let val = v as? String {
                    updated.refreshToken = val
                    changed = true
                }
            }
        }

        // JSON-body token
        if builder.tokenHeaderName == nil, !data.isEmpty,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            if let token = json[builder.tokenJSONField] as? String {
                updated.token = token
                changed = true
            }
            if let field = builder.refreshTokenJSONField,
               let rt = json[field] as? String
            {
                updated.refreshToken = rt
                changed = true
            }
        }

        if changed {
            session = updated
            try await store.save(updated)
        }
    }

    // MARK: - Refresh flow

    private func performRefresh(endpoint: String) async throws {
        guard let rt = session?.refreshToken else {
            throw ZIYONRestError.refreshFailed(nil)
        }

        var ctx = ZIYONRestRequestContext(
            baseURL: builder.baseURL,
            timeoutInterval: builder.config.timeoutInterval,
            config: builder.config
        )
        ctx.pathSegments = [endpoint]
        ctx.method = builder.refreshMethod
        ctx.skipAuth = true
        ctx.headers.merge(builder.refreshExtraHeaders) { _, new in new }
        ctx.body = try executor.encode([builder.refreshRequestField: rt])

        let request = try ctx.buildRequest(authToken: nil)
        let (data, response) = try await executor.execute(request)

        guard (200..<300).contains(response.statusCode) else {
            throw ZIYONRestError.refreshFailed(
                ZIYONRestError.httpError(statusCode: response.statusCode, body: data)
            )
        }

        try await extractAndSaveToken(from: response, data: data)
    }
}

// MARK: - Auth request builder

/// A variant of ``ZIYONRestRequestBuilder`` that fires requests through the auth client,
/// enabling automatic token injection and refresh.
public struct ZIYONRestAuthRequestBuilder: Sendable {

    var context: ZIYONRestRequestContext
    let client: ZIYONRestAuthClient

    // MARK: Path

    public func path(_ segment: some ZIYONRestPathSegment) -> ZIYONRestAuthRequestBuilder {
        var copy = self; copy.context.pathSegments.append(segment.pathString); return copy
    }

    public func paths(_ segments: any ZIYONRestPathSegment...) -> ZIYONRestAuthRequestBuilder {
        var copy = self
        copy.context.pathSegments.append(contentsOf: segments.map(\.pathString))
        return copy
    }

    // MARK: Query

    public func query<T: Encodable & Sendable>(_ model: T) throws -> ZIYONRestAuthRequestBuilder {
        var copy = self
        let data = try context.config.jsonCoding.encoder.encode(model)
        if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (key, value) in dict {
                copy.context.queryItems.append(URLQueryItem(name: key, value: "\(value)"))
            }
        }
        return copy
    }

    public func parameter(_ key: String, _ value: String) -> ZIYONRestAuthRequestBuilder {
        var copy = self; copy.context.queryItems.append(URLQueryItem(name: key, value: value)); return copy
    }

    public func parameters(_ params: [String: String]) -> ZIYONRestAuthRequestBuilder {
        var copy = self
        for (k, v) in params { copy.context.queryItems.append(URLQueryItem(name: k, value: v)) }
        return copy
    }

    // MARK: Headers

    public func header(_ key: String, _ value: String) -> ZIYONRestAuthRequestBuilder {
        var copy = self; copy.context.headers[key] = value; return copy
    }

    public func headers(_ dict: [String: String]) -> ZIYONRestAuthRequestBuilder {
        var copy = self; for (k, v) in dict { copy.context.headers[k] = v }; return copy
    }

    // MARK: Auth override

    public func noAuth() -> ZIYONRestAuthRequestBuilder {
        var copy = self; copy.context.skipAuth = true; return copy
    }

    public func timeout(_ seconds: TimeInterval) -> ZIYONRestAuthRequestBuilder {
        var copy = self; copy.context.timeoutInterval = seconds; return copy
    }

    // MARK: HTTP verbs

    public func get() -> ZIYONRestAuthPendingRequest {
        var copy = self; copy.context.method = .get
        return ZIYONRestAuthPendingRequest(builder: copy)
    }

    public func post<T: Encodable & Sendable>(body: T) throws -> ZIYONRestAuthPendingRequest {
        var copy = self
        copy.context.method = .post
        copy.context.body = try client.encode(body)
        return ZIYONRestAuthPendingRequest(builder: copy)
    }

    public func post() -> ZIYONRestAuthPendingRequest {
        var copy = self; copy.context.method = .post
        return ZIYONRestAuthPendingRequest(builder: copy)
    }

    public func put<T: Encodable & Sendable>(body: T) throws -> ZIYONRestAuthPendingRequest {
        var copy = self
        copy.context.method = .put
        copy.context.body = try client.encode(body)
        return ZIYONRestAuthPendingRequest(builder: copy)
    }

    public func patch<T: Encodable & Sendable>(body: T) throws -> ZIYONRestAuthPendingRequest {
        var copy = self
        copy.context.method = .patch
        copy.context.body = try client.encode(body)
        return ZIYONRestAuthPendingRequest(builder: copy)
    }

    public func delete() -> ZIYONRestAuthPendingRequest {
        var copy = self; copy.context.method = .delete
        return ZIYONRestAuthPendingRequest(builder: copy)
    }

    public func head() -> ZIYONRestAuthPendingRequest {
        var copy = self; copy.context.method = .head
        return ZIYONRestAuthPendingRequest(builder: copy)
    }

    public func options() -> ZIYONRestAuthPendingRequest {
        var copy = self; copy.context.method = .options
        return ZIYONRestAuthPendingRequest(builder: copy)
    }
}

// MARK: - Auth pending request (terminal methods)

public struct ZIYONRestAuthPendingRequest: Sendable {

    let builder: ZIYONRestAuthRequestBuilder

    public func value<T: Decodable & Sendable>() async throws -> T {
        let (data, response) = try await builder.client.fire(context: builder.context)
        let validated = try builder.client.validate(data: data, response: response)
        return try builder.client.decode(T.self, from: validated)
    }

    public func valueAndHeaders<T: Decodable & Sendable>() async throws -> (T, [String: String]) {
        let (data, response) = try await builder.client.fire(context: builder.context)
        let validated = try builder.client.validate(data: data, response: response)
        let decoded: T = try builder.client.decode(T.self, from: validated)
        return (decoded, lowercased(response))
    }

    public func response<T: Decodable & Sendable>() async throws -> ZIYONRestResponse<T> {
        let (data, http) = try await builder.client.fire(context: builder.context)
        let headers = lowercased(http)
        if (200..<300).contains(http.statusCode), !data.isEmpty {
            let decoded: T = try builder.client.decode(T.self, from: data)
            return ZIYONRestResponse(statusCode: http.statusCode, headers: headers, data: decoded)
        }
        return ZIYONRestResponse(statusCode: http.statusCode, headers: headers, data: nil)
    }

    public func raw() async throws -> ZIYONRestRawResponse {
        let (data, http) = try await builder.client.fire(context: builder.context)
        return ZIYONRestRawResponse(httpResponse: http, data: data)
    }

    public func send() async throws {
        let (data, response) = try await builder.client.fire(context: builder.context)
        _ = try builder.client.validate(data: data, response: response)
    }

    private func lowercased(_ response: HTTPURLResponse) -> [String: String] {
        var result: [String: String] = [:]
        for (k, v) in response.allHeaderFields {
            if let key = k as? String, let val = v as? String {
                result[key.lowercased()] = val
            }
        }
        return result
    }
}

// MARK: - Server-Sent Events (SSE) Models & Extension

extension ZIYONRestAuthPendingRequest {

    /// Executes the request and parses a standard Server-Sent Events (SSE) stream.
    /// Yields fully formed events as they are received from the server.
    public func sseStream() async throws -> AsyncThrowingStream<ZIYONServerSentEvent, Error> {

        let session = try await builder.client.currentSession()
        let token = builder.context.skipAuth ? nil : session?.token

        // 1. Resolve the URLRequest locally (URLRequest is a value type and safe to send)
        var request = try builder.context.buildRequest(authToken: token)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        // 2. Use makeStream() to separate the stream from the continuation
        let (stream, continuation) = AsyncThrowingStream<ZIYONServerSentEvent, Error>.makeStream()

        // 3. Spin up the Task. The compiler now explicitly knows we are only
        // capturing the Sendable 'continuation' and value-type 'request'.
        let task = Task {
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }

                guard (200..<300).contains(httpResponse.statusCode) else {
                    throw ZIYONRestError.httpError(statusCode: httpResponse.statusCode, body: Data())
                }

                var currentEvent: String? = "message"
                var currentData: [String] = []
                var currentId: String? = nil
                var currentRetry: Int? = nil

                for try await line in bytes.lines {
                    if line.isEmpty {
                        if !currentData.isEmpty {
                            let event = ZIYONServerSentEvent(
                                event: currentEvent,
                                data: currentData.joined(separator: "\n"),
                                id: currentId,
                                retry: currentRetry
                            )
                            continuation.yield(event)
                        }

                        currentEvent = "message"
                        currentData = []
                        continue
                    }

                    let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                    guard let field = parts.first else { continue }

                    var value = parts.count > 1 ? String(parts[1]) : ""
                    if value.hasPrefix(" ") { value.removeFirst() }

                    switch field {
                    case "event": currentEvent = value
                    case "data":  currentData.append(value)
                    case "id":    currentId = value
                    case "retry": currentRetry = Int(value)
                    case "":      continue
                    default:      continue
                    }
                }

                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }

        // 4. Securely bind cancellation outside the Task boundary
        continuation.onTermination = { @Sendable _ in
            task.cancel()
        }

        // 5. Return the stream to the caller
        return stream
    }

}

// MARK: - Plain Client SSE Extension

extension ZIYONRestPendingRequest {

    /// Executes the request and parses a standard Server-Sent Events (SSE) stream.
    /// Yields fully formed events as they are received from the server.
    public func sseStream() async throws -> AsyncThrowingStream<ZIYONServerSentEvent, Error> {

        // The plain client doesn't manage sessions, so we pass nil for the token
        var request = try builder.context.buildRequest(authToken: nil)

        // Force headers required for a stable SSE connection
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let (stream, continuation) = AsyncThrowingStream<ZIYONServerSentEvent, Error>.makeStream()

        let task = Task {
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }

                guard (200..<300).contains(httpResponse.statusCode) else {
                    throw ZIYONRestError.httpError(statusCode: httpResponse.statusCode, body: Data())
                }

                var currentEvent: String? = "message"
                var currentData: [String] = []
                var currentId: String? = nil
                var currentRetry: Int? = nil

                for try await line in bytes.lines {
                    if line.isEmpty {
                        if !currentData.isEmpty {
                            let event = ZIYONServerSentEvent(
                                event: currentEvent,
                                data: currentData.joined(separator: "\n"),
                                id: currentId,
                                retry: currentRetry
                            )
                            continuation.yield(event)
                        }

                        currentEvent = "message"
                        currentData = []
                        continue
                    }

                    let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                    guard let field = parts.first else { continue }

                    var value = parts.count > 1 ? String(parts[1]) : ""
                    if value.hasPrefix(" ") { value.removeFirst() }

                    switch field {
                    case "event": currentEvent = value
                    case "data":  currentData.append(value)
                    case "id":    currentId = value
                    case "retry": currentRetry = Int(value)
                    case "":      continue
                    default:      continue
                    }
                }

                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }

        continuation.onTermination = { @Sendable _ in
            task.cancel()
        }

        return stream
    }
}
