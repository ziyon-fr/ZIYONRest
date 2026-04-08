# ZIYONRest

[![Swift 6](https://img.shields.io/badge/Swift-6.0+-F05138.svg)](https://www.swift.org/)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2016%20%7C%20macOS%2013-blue.svg)](https://developer.apple.com/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**ZIYONRest** is a production-ready, Swift 6 concurrency-safe REST client built by [ZIYON SAS](https://ziyon.co). It is actor-isolated end-to-end, supports file downloads with progress streaming, silent token refresh, Keychain persistence, multipart uploads, and pagination — with a fluent, beginner-friendly API.

---

## Contents

- [Requirements](#requirements)
- [Install](#install)
- [Quick Start](#quick-start)
- [Plain Client](#plain-client)
- [Auth & Session Client](#auth--session-client)
- [Storage Options](#storage-options)
- [Token Mapping](#token-mapping)
- [Login, Refresh & Logout](#login-refresh--logout)
- [Headers](#headers)
- [Path & Query](#path--query)
- [HTTP Methods](#http-methods)
- [Multipart Uploads](#multipart-uploads)
- [Downloads](#downloads)
- [Pagination](#pagination)
- [JSON Options](#json-options)
- [Retry Policy](#retry-policy)
- [Logging](#logging)
- [Error Handling](#error-handling)
- [Testing](#testing)
- [SwiftUI Example](#swiftui-example)

---

## Requirements

| | Minimum |
|---|---|
| Swift | 6.0 |
| iOS | 16 |
| macOS | 13 |

---

## Install

Add ZIYONRest via Swift Package Manager:

```swift
// Package.swift
.package(url: "https://github.com/ziyon/ZIYONRest.git", from: "1.0.0")
```

Then add `"ZIYONRest"` to your target's dependencies.

---

## Quick Start

```swift
import ZIYONRest

struct Product: Decodable, Sendable {
    let id: Int
    let name: String
}

let client = ZIYONRest.client(baseURL: URL(string: "https://api.ziyon.co")!)

let product: Product = try await client
    .path("v1/products")
    .path(42)
    .get()
    .value()
```

---

## Plain Client

Use the plain client for endpoints that don't require authentication.

```swift
let client = ZIYONRest.client(baseURL: apiURL)

// GET → decode
let product: Product = try await client.path("v1/products/1").get().value()

// GET → raw (no throw on non-2xx)
let raw = try await client.path("v1/health").get().raw()
print(raw.statusCode)

// GET → typed envelope with headers
let (product, headers): (Product, [String: String]) = try await client
    .path("v1/products/1")
    .get()
    .valueAndHeaders()
print(headers["x-request-id"] ?? "none")
```

### Configuration preset

```swift
// snake_case keys + ISO 8601 dates
let client = ZIYONRest.client(baseURL: apiURL, config: .webAPI)
```

---

## Auth & Session Client

The auth client stores tokens, attaches them as `Authorization: Bearer` on every request, and silently refreshes them on `401`.

```swift
let auth = ZIYONRest
    .auth(baseURL: apiURL)
    .keychain()                            // Keychain persistence (default)
    .tokenField("accessToken")             // JSON field → access token
    .refreshTokenField("refreshToken")     // JSON field → refresh token
    .refresh(endpoint: "v1/auth/refresh")  // silent refresh on 401
    .logging(.basic)                       // console logging
    .client

let profile: Profile = try await auth.path("v1/me").get().value()
```

---

## Storage Options

| Method | Description |
|--------|-------------|
| `.keychain()` | System Keychain (default, recommended) |
| `.defaults()` | `UserDefaults` |
| `.memory()` | In-memory, lost on restart |
| `.none()` | No persistence |
| `.store(myStore)` | Custom `ZIYONRestSessionStore` conformance |

```swift
// Custom store
actor AppSessionStore: ZIYONRestSessionStore {
    private var session: ZIYONRestAuthSession?
    func load() async throws -> ZIYONRestAuthSession? { session }
    func save(_ s: ZIYONRestAuthSession) async throws { session = s }
    func clear() async throws { session = nil }
}

let auth = ZIYONRest.auth(baseURL: apiURL).store(AppSessionStore()).client
```

---

## Token Mapping

### JSON body tokens

```swift
let auth = ZIYONRest
    .auth(baseURL: apiURL)
    .tokenField("sessionToken")
    .refreshTokenField("sessionRefreshToken")
    .client
```

### Response header tokens

```swift
let auth = ZIYONRest
    .auth(baseURL: apiURL)
    .tokenHeader("X-Session-Token")
    .refreshTokenHeader("X-Refresh-Token")
    .client
```

---

## Login, Refresh & Logout

```swift
struct LoginRequest: Encodable, Sendable { let email: String; let password: String }
struct LoginResponse: Decodable, Sendable { let accessToken: String }

// Login — tokens are saved automatically
let _: LoginResponse = try await auth
    .path("v1/auth/login")
    .noAuth()
    .post(body: LoginRequest(email: "elione@ziyon.co", password: "••••"))
    .value()

// Check stored session
if let s = try await auth.currentSession() {
    print(s.token ?? "no token")
}

// Save tokens manually
try await auth.save(token: "my-token", refreshToken: "my-refresh")

// Logout
try await auth.logout()
```

---

## Headers

### Global per-client headers

```swift
let auth = ZIYONRest
    .auth(baseURL: apiURL)
    .header("X-App-Version", "1.0.0")
    .header("X-Platform", "iOS")
    .client
```

### Per-request headers

```swift
let result: Profile = try await auth
    .path("v1/me")
    .header("X-Trace-ID", UUID().uuidString)
    .get()
    .value()
```

---

## Path & Query

```swift
// Chain path segments — no need to add "/"
let user: User = try await client
    .path("v1").path("users").path(42).path(UUID())
    .get().value()

// Append multiple at once
let user: User = try await client
    .path("v1").paths("users", 42)
    .get().value()

// Typed query model
struct UserQuery: Encodable, Sendable { let page: Int; let search: String }
let users: [User] = try await client
    .path("v1/users")
    .query(UserQuery(page: 1, search: "elione"))
    .get().value()

// Ad-hoc parameters
let users: [User] = try await client
    .path("v1/users")
    .parameter("page", "1")
    .parameter("search", "elione")
    .get().value()
```

---

## HTTP Methods

```swift
// GET
let product: Product = try await client.path("v1/products/1").get().value()

// POST with body
let created: Product = try await client
    .path("v1/products")
    .post(body: CreateProduct(name: "Widget"))
    .value()

// PUT
let updated: Product = try await client
    .path("v1/products/1")
    .put(body: UpdateProduct(name: "Gadget"))
    .value()

// PATCH
let patched: Product = try await client
    .path("v1/products/1")
    .patch(body: ["name": "Pro Widget"])
    .value()

// DELETE
try await client.path("v1/products/1").delete().send()

// HEAD
let head = try await client.path("v1/health").head().raw()

// OPTIONS
let options = try await client.path("v1/products").options().raw()
print(options.header("allow") ?? "none")
```

---

## Multipart Uploads

```swift
var form = ZIYONRestMultipartForm()
form.addField(name: "description", value: "Product photo")
form.addData(
    name: "photo",
    data: jpegData,
    filename: "photo.jpg",
    mimeType: "image/jpeg"
)

let result: UploadResult = try await auth
    .path("v1/uploads")
    .post(multipart: form)
    .value()
```

---

## Downloads

```swift
let downloader = ZIYONRestDownloader(
    config: .standard,
    authToken: try await auth.currentSession()?.token
)

let destination = FileManager.default
    .urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("report.pdf")

let remoteURL = URL(string: "https://api.ziyon.co/files/report.pdf")!

// Stream progress
for await progress in try await downloader.download(url: remoteURL, destination: destination) {
    print("\(progress.percentString) — \(progress.bytesWritten.formattedByteCount)")
}

// Get the final result
let result = try await downloader.result(for: remoteURL)
print("Saved to: \(result.fileURL.path)")

// Pause / resume
downloader.pause(url: remoteURL)
for await progress in try await downloader.resume(url: remoteURL, destination: destination) { ... }

// Cancel
downloader.cancel(url: remoteURL)
```

---

## Pagination

Define your page envelope (or use the built-in one) and call `.page()`:

```swift
// Built-in envelope: { "data": [...], "total": 100, "current_page": 1, "total_pages": 5 }
let page: ZIYONRestPage<Product> = try await client
    .path("v1/products")
    .parameter("page", "1")
    .get()
    .page()

print("Items: \(page.items.count)")
print("Has more: \(page.hasMore)")
print("Total: \(page.total ?? 0)")
```

---

## JSON Options

```swift
// Preset
let client = ZIYONRest.client(baseURL: apiURL, config: .webAPI)

// Auth builder
let auth = ZIYONRest
    .auth(baseURL: apiURL)
    .jsonCoding(.webAPIFractionalSeconds)
    .client
```

| Preset | Keys | Dates |
|--------|------|-------|
| `.default` | as-is | Foundation default |
| `.webAPI` | snake_case | ISO 8601 |
| `.webAPIFractionalSeconds` | snake_case | ISO 8601 + ms |
| `.iso8601` | as-is | ISO 8601 |
| `.unixSeconds` | as-is | Unix seconds |
| `.unixMilliseconds` | as-is | Unix milliseconds |

---

## Retry Policy

```swift
let auth = ZIYONRest
    .auth(baseURL: apiURL)
    .retry(.aggressive) // 5 attempts, 1 s base delay, 30 s cap
    .client

// Or custom
let policy = ZIYONRestRetryPolicy(
    maxAttempts: 4,
    baseDelay: 0.25,
    maxDelay: 8,
    retryableStatusCodes: [429, 503]
)
```

---

## Logging

```swift
let auth = ZIYONRest
    .auth(baseURL: apiURL)
    .logging(.verbose) // .none | .basic | .headers | .verbose
    .client
```

Output goes to `os.Logger` under the `com.ziyon.rest` subsystem so it appears in Console.app.

---

## Error Handling

```swift
do {
    let profile: Profile = try await auth.path("v1/me").get().value()
} catch let error as ZIYONRestError {
    switch error {
    case .httpError(let code, _):   print("HTTP \(code)")
    case .networkError(let e):      print("Network: \(e)")
    case .decodingFailed(let e):    print("Decode: \(e)")
    case .refreshFailed(let e):     print("Refresh: \(String(describing: e))")
    case .cancelled:                print("Cancelled")
    case .downloadError(let e):     print("Download: \(e)")
    default:                        print(error.localizedDescription)
    }
} catch {
    print(error)
}
```

---

## Testing

ZIYONRest ships a `ZIYONRestMock` URLProtocol (compiled in `#if DEBUG` only) for unit testing without a real network.

```swift
import Testing
@testable import ZIYONRest

@Test("Fetches product")
func fetchProduct() async throws {
    let product = Product(id: 1, name: "Widget")
    ZIYONRestMock.stub(url: "https://api.ziyon.co/v1/products/1") {
        try! .json(product)
    }
    let client = ZIYONRest.client(
        baseURL: URL(string: "https://api.ziyon.co")!,
        session: ZIYONRestMock.session
    )
    let fetched: Product = try await client.path("v1/products/1").get().value()
    #expect(fetched.name == "Widget")
}
```

---

## SwiftUI Example

```swift
import SwiftUI
import ZIYONRest

@MainActor
final class ProductViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var error: String?

    private let auth: ZIYONRestAuthClient

    init(auth: ZIYONRestAuthClient) { self.auth = auth }

    func load() async {
        do {
            let page: ZIYONRestPage<Product> = try await auth
                .path("v1/products")
                .parameter("page", "1")
                .get()
                .page()
            products = page.items
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ProductListView: View {
    @StateObject private var vm: ProductViewModel

    init(auth: ZIYONRestAuthClient) {
        _vm = StateObject(wrappedValue: ProductViewModel(auth: auth))
    }

    var body: some View {
        List(vm.products, id: \.id) { product in
            Text(product.name)
        }
        .task { await vm.load() }
        .alert("Error", isPresented: .constant(vm.error != nil)) {
            Button("OK") { vm.error = nil }
        } message: {
            Text(vm.error ?? "")
        }
    }
}
```

---

## License

ZIYONRest is released under the [MIT License](LICENSE).  
Copyright © 2025 ZIYON SAS. All rights reserved.
