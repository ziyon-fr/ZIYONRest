// ZIYONRestMock.swift
// ZIYON SAS - Swift 6 REST Client

#if DEBUG
import Foundation

// MARK: - Mock URL protocol

/// A `URLProtocol` subclass that intercepts requests and returns pre-configured stubs.
/// Use in unit tests to avoid hitting real network endpoints.
///
/// ```swift
/// ZIYONRestMock.stub(url: "https://api.example.com/users/1") {
///     ZIYONRestMockResponse(
///         statusCode: 200,
///         body: try! JSONEncoder().encode(user),
///         headers: ["Content-Type": "application/json"]
///     )
/// }
///
/// let session = URLSession(configuration: ZIYONRestMock.sessionConfiguration)
/// let client = ZIYONRest.client(baseURL: apiURL, session: session)
/// ```
public final class ZIYONRestMock: URLProtocol, @unchecked Sendable {

    // MARK: - Stub registry

    public struct MockResponse: Sendable {
        public let statusCode: Int
        public let body: Data?
        public let headers: [String: String]
        public let delay: TimeInterval

        public init(
            statusCode: Int = 200,
            body: Data? = nil,
            headers: [String: String] = ["Content-Type": "application/json"],
            delay: TimeInterval = 0
        ) {
            self.statusCode = statusCode
            self.body = body
            self.headers = headers
            self.delay = delay
        }

        /// Convenience: encode a `Codable` value as the JSON body.
        public static func json<T: Encodable>(
            _ value: T,
            statusCode: Int = 200,
            headers: [String: String] = ["Content-Type": "application/json"],
            delay: TimeInterval = 0
        ) throws -> MockResponse {
            let data = try JSONEncoder().encode(value)
            return MockResponse(statusCode: statusCode, body: data, headers: headers, delay: delay)
        }
    }

    nonisolated(unsafe) private static var stubs: [String: () -> MockResponse] = [:]
    private static let lock = NSLock()

    /// Registers a stub for the given URL string.
    public static func stub(url: String, response: @escaping () -> MockResponse) {
        lock.lock()
        defer { lock.unlock() }
        stubs[url] = response
    }

    /// Removes all registered stubs.
    public static func reset() {
        lock.lock()
        defer { lock.unlock() }
        stubs = [:]
    }

    /// A `URLSessionConfiguration` pre-loaded with this protocol.
    public static var sessionConfiguration: URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ZIYONRestMock.self]
        return config
    }

    /// A ready-to-use `URLSession` using mock configuration.
    public static var session: URLSession {
        URLSession(configuration: sessionConfiguration)
    }

    // MARK: - URLProtocol

    public override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url?.absoluteString else { return false }
        lock.lock()
        defer { lock.unlock() }
        return stubs[url] != nil
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    public override func startLoading() {
        guard let url = request.url?.absoluteString else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        Self.lock.lock()
        let factory = Self.stubs[url]
        Self.lock.unlock()

        guard let factory else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        let mock = factory()

        DispatchQueue.global().asyncAfter(deadline: .now() + mock.delay) { [weak self] in
            guard let self else { return }
            let httpResponse = HTTPURLResponse(
                url: self.request.url!,
                statusCode: mock.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: mock.headers
            )!
            self.client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            if let body = mock.body {
                self.client?.urlProtocol(self, didLoad: body)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }

    public override func stopLoading() {}
}

// MARK: - Type alias for external clarity

public typealias ZIYONRestMockResponse = ZIYONRestMock.MockResponse
#endif
