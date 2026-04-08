// ZIYONRestClient.swift
// ZIYON SAS - Swift 6 REST Client

import Foundation

// MARK: - Plain client

/// An unauthenticated, actor-isolated HTTP client.
///
/// Use ``ZIYONRest/client(baseURL:config:session:)`` to create one.
public actor ZIYONRestClient {

    let baseURL: URL
    let config: ZIYONRestConfig
    let executor: ZIYONRestExecutor

    init(baseURL: URL, config: ZIYONRestConfig, session: URLSession) {
        self.baseURL = baseURL
        self.config = config
        self.executor = ZIYONRestExecutor(session: session, config: config)
    }

    // MARK: - Request builder entry point

    /// Starts a request chain by appending the first path segment.
    ///
    /// ```swift
    /// let user: User = try await client.path("users").path(1).get().value()
    /// ```
    public func path(_ segment: some ZIYONRestPathSegment) -> ZIYONRestRequestBuilder {
        var ctx = ZIYONRestRequestContext(
            baseURL: baseURL,
            timeoutInterval: config.timeoutInterval,
            config: config
        )
        ctx.pathSegments.append(segment.pathString)
        return ZIYONRestRequestBuilder(context: ctx, executor: executor, authToken: nil)
    }

    /// Starts a request chain with a URL path appended to the base URL.
    public func path(url: URL) -> ZIYONRestRequestBuilder {
        let ctx = ZIYONRestRequestContext(
            baseURL: baseURL.appendingPathComponent(url.path),
            timeoutInterval: config.timeoutInterval,
            config: config
        )
        return ZIYONRestRequestBuilder(context: ctx, executor: executor, authToken: nil)
    }
}

// MARK: - Path segment protocol

/// Types that can appear as path segments in a request chain.
public protocol ZIYONRestPathSegment: Sendable {
    var pathString: String { get }
}

extension String: ZIYONRestPathSegment {
    public var pathString: String { self }
}
extension Int: ZIYONRestPathSegment {
    public var pathString: String { String(self) }
}
extension Int64: ZIYONRestPathSegment {
    public var pathString: String { String(self) }
}
extension UInt: ZIYONRestPathSegment {
    public var pathString: String { String(self) }
}
extension Double: ZIYONRestPathSegment {
    public var pathString: String { String(self) }
}
extension Float: ZIYONRestPathSegment {
    public var pathString: String { String(self) }
}
extension UUID: ZIYONRestPathSegment {
    public var pathString: String { uuidString }
}
extension Bool: ZIYONRestPathSegment {
    public var pathString: String { description }
}
