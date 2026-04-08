// ZIYONRestExecutor.swift
// ZIYON SAS — Swift 6 REST Client

import Foundation

// MARK: — HTTP executor

/// Sends `URLRequest`s with retry, logging, and error normalisation.
/// Shared between the plain client and the auth client.
actor ZIYONRestExecutor {

    let session: URLSession
    let config: ZIYONRestConfig

    init(session: URLSession, config: ZIYONRestConfig) {
        self.session = session
        self.config = config
    }

    // MARK: Execute

    /// Fires the request and returns raw bytes + response. Retries on transient errors.
    func execute(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let policy = config.retryPolicy
        var lastError: Error = ZIYONRestError.unknown("No attempts made")

        for attempt in 0...policy.maxAttempts {
            if attempt > 0 {
                let delay = policy.delay(forAttempt: attempt - 1)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            do {
                let (data, response) = try await session.data(for: request)

                guard let http = response as? HTTPURLResponse else {
                    throw ZIYONRestError.unknown("Non-HTTP response")
                }

                ZIYONRestLogger.log(
                    level: config.logging,
                    request: request,
                    response: http,
                    data: data,
                    error: nil
                )

                // Retry on server errors
                if policy.shouldRetry(statusCode: http.statusCode), attempt < policy.maxAttempts {
                    lastError = ZIYONRestError.httpError(statusCode: http.statusCode, body: data)
                    continue
                }

                return (data, http)

            } catch is CancellationError {
                throw ZIYONRestError.cancelled
            } catch let e as ZIYONRestError {
                throw e
            } catch {
                ZIYONRestLogger.log(
                    level: config.logging,
                    request: request,
                    response: nil,
                    data: nil,
                    error: error
                )
                lastError = ZIYONRestError.networkError(error)
                if attempt < policy.maxAttempts { continue }
            }
        }

        throw lastError
    }
}

// MARK: — Response helpers

extension ZIYONRestExecutor {

    /// Validate HTTP status (throws on non-2xx) and return the raw bytes.
    nonisolated func validate(data: Data, response: HTTPURLResponse) throws -> Data {
        guard (200..<300).contains(response.statusCode) else {
            throw ZIYONRestError.httpError(statusCode: response.statusCode, body: data)
        }
        return data
    }

    /// Decode bytes into `T`.
    nonisolated func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try config.jsonCoding.decoder.decode(type, from: data)
        } catch {
            throw ZIYONRestError.decodingFailed(error)
        }
    }

    /// Encode `body` to JSON bytes.
    nonisolated func encode<T: Encodable>(_ body: T) throws -> Data {
        do {
            return try config.jsonCoding.encoder.encode(body)
        } catch {
            throw ZIYONRestError.encodingFailed(error)
        }
    }
}
