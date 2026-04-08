// ZIYONRestRetryPolicy.swift
// ZIYON SAS - Swift 6 REST Client

import Foundation

// MARK: - Retry Policy

/// Controls how and when failed requests are retried.
public struct ZIYONRestRetryPolicy: Sendable {

    /// Maximum number of retry attempts (not counting the original request).
    public var maxAttempts: Int

    /// Base delay between retries in seconds. Actual delay uses exponential back-off:
    /// `baseDelay * 2^attempt` capped at `maxDelay`.
    public var baseDelay: TimeInterval

    /// Maximum delay cap in seconds.
    public var maxDelay: TimeInterval

    /// HTTP status codes that trigger a retry.
    public var retryableStatusCodes: Set<Int>

    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 0.5,
        maxDelay: TimeInterval = 10,
        retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504]
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.retryableStatusCodes = retryableStatusCodes
    }

    // MARK: Presets

    /// Standard retry: 3 attempts, exponential back-off, common server errors.
    public static let standard = ZIYONRestRetryPolicy()

    /// No retries at all.
    public static let none = ZIYONRestRetryPolicy(maxAttempts: 0)

    /// Aggressive retry: 5 attempts with 1 s base delay.
    public static let aggressive = ZIYONRestRetryPolicy(
        maxAttempts: 5,
        baseDelay: 1,
        maxDelay: 30
    )

    // MARK: Helpers

    /// The delay before the given attempt (0-indexed).
    func delay(forAttempt attempt: Int) -> TimeInterval {
        let raw = baseDelay * pow(2.0, Double(attempt))
        return min(raw, maxDelay)
    }

    func shouldRetry(statusCode: Int) -> Bool {
        retryableStatusCodes.contains(statusCode)
    }
}
