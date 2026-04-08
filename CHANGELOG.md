# Changelog

All notable changes to **ZIYONRest** will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
ZIYONRest uses [Semantic Versioning](https://semver.org/).

---

## [1.0.0] – 2025-04-08

### Added

- `ZIYONRestClient` — actor-isolated plain HTTP client with fluent builder API.
- `ZIYONRestAuthClient` — actor-isolated auth client with Keychain, UserDefaults,
  memory, null, and custom session stores.
- `ZIYONRestAuthBuilder` — fluent builder for the auth client (token fields, refresh
  endpoint, storage preset, headers, timeout, retry, logging, JSON coding).
- `ZIYONRestDownloader` — actor-isolated download manager with `AsyncStream` progress,
  pause / resume, cancellation, and auth token injection.
- `ZIYONRestMultipartForm` — `multipart/form-data` body builder usable from both
  plain and auth request builders.
- `ZIYONRestPage<T>` and `ZIYONRestPageEnvelope<T>` — typed pagination support with
  `.page()` terminal method on `PendingRequest` and `AuthPendingRequest`.
- `ZIYONRestMock` — `URLProtocol`-based stub system for unit testing (compiled only
  in `DEBUG` builds).
- `ZIYONRestJSONCoding` presets: `.default`, `.webAPI`, `.webAPIFractionalSeconds`,
  `.iso8601`, `.unixSeconds`, `.unixMilliseconds`.
- `ZIYONRestRetryPolicy` with exponential back-off, configurable retryable status
  codes, and presets: `.standard`, `.none`, `.aggressive`.
- `ZIYONRestLogging` levels: `.none`, `.basic`, `.headers`, `.verbose` — output via
  `os.Logger` under the `com.ziyon.rest` subsystem.
- Swift Testing suite covering URL construction, HTTP verbs, session stores,
  multipart encoding, pagination, and download progress.
- Full DocC-compatible documentation on every public type and method.
- MIT license.
