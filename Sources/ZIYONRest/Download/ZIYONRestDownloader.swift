// ZIYONRestDownloader.swift
// ZIYON SAS — Swift 6 REST Client

import Foundation

// MARK: — Download progress

/// A snapshot of an in-progress download.
public struct ZIYONRestDownloadProgress: Sendable {
    /// Bytes written so far.
    public let bytesWritten: Int64
    /// Total expected bytes, or `-1` if the server did not report Content-Length.
    public let totalBytes: Int64
    /// Fraction complete in [0, 1], or `nil` if total is unknown.
    public var fractionCompleted: Double? {
        guard totalBytes > 0 else { return nil }
        return Double(bytesWritten) / Double(totalBytes)
    }
    /// Human-readable percentage string, e.g. "42%".
    public var percentString: String {
        guard let f = fractionCompleted else { return "?" }
        return "\(Int(f * 100))%"
    }
}

// MARK: — Download result

/// The result of a completed download.
public struct ZIYONRestDownloadResult: Sendable {
    /// The URL where the file was saved.
    public let fileURL: URL
    /// Total bytes written.
    public let totalBytesWritten: Int64
    /// All response headers (lowercased keys).
    public let headers: [String: String]
    /// HTTP status code.
    public let statusCode: Int
}

// MARK: — Download task state

private enum DownloadState: Sendable {
    case idle
    case running
    case paused(resumeData: Data)
    case finished(ZIYONRestDownloadResult)
    case failed(Error)
}

// MARK: — Downloader

/// An actor that manages one or more file downloads with progress reporting,
/// pause / resume, cancellation, and background-safe delivery.
///
/// ```swift
/// let downloader = ZIYONRestDownloader()
///
/// for await progress in try await downloader.download(
///     url: fileURL,
///     destination: localURL
/// ) {
///     print(progress.percentString)
/// }
///
/// let result = try await downloader.result(for: fileURL)
/// ```
public actor ZIYONRestDownloader {

    // MARK: Configuration

    private let session: URLSession
    private let config: ZIYONRestConfig
    private var extraHeaders: [String: String]
    private var authToken: String?

    // MARK: State tracking

    private var tasks: [URL: URLSessionDownloadTask] = [:]
    private var states: [URL: DownloadState] = [:]
    private var continuations: [URL: AsyncStream<ZIYONRestDownloadProgress>.Continuation] = [:]
    private var delegates: [URL: DownloadDelegate] = [:]

    // MARK: Init

    public init(
        session: URLSession = .shared,
        config: ZIYONRestConfig = .standard,
        headers: [String: String] = [:],
        authToken: String? = nil
    ) {
        self.session = session
        self.config = config
        self.extraHeaders = headers
        self.authToken = authToken
    }

    // MARK: — Token injection

    /// Updates the auth token injected into download requests.
    public func setAuthToken(_ token: String?) {
        authToken = token
    }

    // MARK: — Download

    /// Downloads a remote URL to `destination`, streaming progress updates.
    ///
    /// ```swift
    /// for await progress in try await downloader.download(url: remote, destination: local) {
    ///     updateUI(progress)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - url:         The remote URL to download.
    ///   - destination: Where to save the file locally.
    ///   - overwrite:   If `true`, replaces an existing file at the destination. Default: `true`.
    /// - Returns:       An `AsyncStream` of ``ZIYONRestDownloadProgress`` snapshots.
    /// - Throws:        ``ZIYONRestDownloadError/alreadyRunning`` if a download for this URL is already active.
    public func download(
        url: URL,
        destination: URL,
        overwrite: Bool = true
    ) async throws -> AsyncStream<ZIYONRestDownloadProgress> {
        if case .running = states[url] {
            throw ZIYONRestError.downloadError(.alreadyRunning)
        }

        states[url] = .running

        let request = buildRequest(url: url)

        let (stream, continuation) = AsyncStream<ZIYONRestDownloadProgress>.makeStream()
        continuations[url] = continuation

        let delegate = DownloadDelegate(
            url: url,
            destination: destination,
            overwrite: overwrite,
            config: config
        ) { [weak self] event in
            guard let self else { return }
            Task { await self.handle(event: event, for: url) }
        }

        delegates[url] = delegate

        let delegateSession = URLSession(
            configuration: session.configuration,
            delegate: delegate,
            delegateQueue: nil
        )

        let task = delegateSession.downloadTask(with: request)
        tasks[url] = task
        task.resume()

        return stream
    }

    /// Downloads a remote URL to `destination` using resume data from a previous interrupted download.
    public func resume(
        url: URL,
        destination: URL
    ) async throws -> AsyncStream<ZIYONRestDownloadProgress> {
        guard case .paused(let data) = states[url] else {
            throw ZIYONRestError.downloadError(.invalidResumeData)
        }

        states[url] = .running

        let (stream, continuation) = AsyncStream<ZIYONRestDownloadProgress>.makeStream()
        continuations[url] = continuation

        let delegate = DownloadDelegate(
            url: url,
            destination: destination,
            overwrite: true,
            config: config
        ) { [weak self] event in
            guard let self else { return }
            Task { await self.handle(event: event, for: url) }
        }

        delegates[url] = delegate

        let delegateSession = URLSession(
            configuration: session.configuration,
            delegate: delegate,
            delegateQueue: nil
        )

        let task = delegateSession.downloadTask(withResumeData: data)
        tasks[url] = task
        task.resume()

        return stream
    }

    // MARK: — Control

    /// Pauses the download and saves resume data (if supported by the server).
    public func pause(url: URL) {
        guard let task = tasks[url] else { return }
        task.cancel { [weak self] resumeData in
            guard let self else { return }
            Task {
                if let data = resumeData {
                    await self.setState(.paused(resumeData: data), for: url)
                } else {
                    await self.setState(.idle, for: url)
                }
                await self.finish(url: url)
            }
        }
    }

    /// Cancels the download entirely.
    public func cancel(url: URL) {
        tasks[url]?.cancel()
        tasks[url] = nil
        states[url] = .idle
        finish(url: url)
    }

    // MARK: — Result

    /// Returns the finished result once available. Throws if the download failed.
    public func result(for url: URL) async throws -> ZIYONRestDownloadResult {
        switch states[url] {
        case .finished(let result): return result
        case .failed(let error): throw error
        default:
            throw ZIYONRestError.unknown("No finished download for \(url)")
        }
    }

    /// Returns `true` if a download is currently running for the given URL.
    public func isDownloading(url: URL) -> Bool {
        if case .running = states[url] { return true }
        return false
    }

    // MARK: — Internal

    private func handle(event: DownloadEvent, for url: URL) {
        switch event {
        case .progress(let written, let total):
            let p = ZIYONRestDownloadProgress(bytesWritten: written, totalBytes: total)
            continuations[url]?.yield(p)

        case .finished(let result):
            states[url] = .finished(result)
            continuations[url]?.finish()
            finish(url: url)

        case .failed(let error):
            states[url] = .failed(error)
            continuations[url]?.finish()
            finish(url: url)
        }
    }

    private func setState(_ state: DownloadState, for url: URL) {
        states[url] = state
    }

    private func finish(url: URL) {
        continuations[url] = nil
        delegates[url] = nil
        tasks[url] = nil
    }

    private func buildRequest(url: URL) -> URLRequest {
        var req = URLRequest(url: url, timeoutInterval: config.timeoutInterval)
        req.httpMethod = "GET"
        for (k, v) in config.baseHeaders { req.setValue(v, forHTTPHeaderField: k) }
        for (k, v) in extraHeaders { req.setValue(v, forHTTPHeaderField: k) }
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }
}

// MARK: — Download events

private enum DownloadEvent: Sendable {
    case progress(bytesWritten: Int64, totalBytes: Int64)
    case finished(ZIYONRestDownloadResult)
    case failed(Error)
}

// MARK: — URLSessionDownloadDelegate bridge

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

    private let url: URL
    private let destination: URL
    private let overwrite: Bool
    private let config: ZIYONRestConfig
    private let callback: @Sendable (DownloadEvent) -> Void

    private var bytesWritten: Int64 = 0
    private var totalBytes: Int64 = -1

    init(
        url: URL,
        destination: URL,
        overwrite: Bool,
        config: ZIYONRestConfig,
        callback: @escaping @Sendable (DownloadEvent) -> Void
    ) {
        self.url = url
        self.destination = destination
        self.overwrite = overwrite
        self.config = config
        self.callback = callback
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        bytesWritten = totalBytesWritten
        totalBytes = totalBytesExpectedToWrite
        callback(.progress(bytesWritten: totalBytesWritten, totalBytes: totalBytesExpectedToWrite))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let fm = FileManager.default
        do {
            if overwrite, fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.moveItem(at: location, to: destination)

            var headers: [String: String] = [:]
            if let http = downloadTask.response as? HTTPURLResponse {
                for (k, v) in http.allHeaderFields {
                    if let key = k as? String, let val = v as? String {
                        headers[key.lowercased()] = val
                    }
                }
                ZIYONRestLogger.logDownload(
                    url: url,
                    destination: destination,
                    bytesWritten: bytesWritten,
                    totalBytes: totalBytes
                )
                let result = ZIYONRestDownloadResult(
                    fileURL: destination,
                    totalBytesWritten: bytesWritten,
                    headers: headers,
                    statusCode: http.statusCode
                )
                callback(.finished(result))
            } else {
                callback(.failed(ZIYONRestError.downloadError(.invalidResponse)))
            }
        } catch {
            callback(.failed(ZIYONRestError.downloadError(.moveFileFailed(destination, error))))
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            callback(.failed(ZIYONRestError.networkError(error)))
        }
    }
}
