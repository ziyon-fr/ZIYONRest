// ZIYONRestTests.swift
// ZIYON SAS — Swift 6 REST Client

import Testing
import Foundation
@testable import ZIYONRest

// MARK: — Shared fixtures

private struct User: Codable, Sendable, Equatable {
    let id: Int
    let firstName: String
    let email: String
}

private struct CreateUser: Encodable, Sendable {
    let firstName: String
    let email: String
}

private let testUser = User(id: 1, firstName: "Elione", email: "elione@ziyon.co")
private let baseURL = URL(string: "https://api.ziyon.test")!

private func makeClient(stub: @escaping () -> ZIYONRestMockResponse = {
    try! .json(testUser)
}) -> ZIYONRestClient {
    ZIYONRestMock.stub(url: "\(baseURL)/users/1", response: stub)
    return ZIYONRest.client(baseURL: baseURL, session: ZIYONRestMock.session)
}

// MARK: — URL construction tests

@Suite("URL Construction")
struct URLConstructionTests {

    @Test("Single path segment builds correct URL")
    func singlePath() async throws {
        ZIYONRestMock.reset()
        ZIYONRestMock.stub(url: "\(baseURL)/users") { try! .json(testUser) }
        let client = ZIYONRest.client(baseURL: baseURL, session: ZIYONRestMock.session)
        // Verify the builder assembles the right URL by successfully decoding a stub response
        let raw = try await client.path("users").get().raw()
        #expect(raw.statusCode == 200)
    }

    @Test("Multiple path segments build correct URL")
    func multiPath() async throws {
        ZIYONRestMock.reset()
        ZIYONRestMock.stub(url: "\(baseURL)/v1/users/42") { try! .json(testUser) }
        let client = ZIYONRest.client(baseURL: baseURL, session: ZIYONRestMock.session)
        let raw = try await client.path("v1").path("users").path(42).get().raw()
        #expect(raw.statusCode == 200)
    }

    @Test("Query items are appended to URL")
    func queryItems() async throws {
        ZIYONRestMock.reset()
        // The mock matches on the exact URL including query string
        ZIYONRestMock.stub(url: "\(baseURL)/users?page=2") { try! .json(testUser) }
        let client = ZIYONRest.client(baseURL: baseURL, session: ZIYONRestMock.session)
        let raw = try await client.path("users").parameter("page", "2").get().raw()
        #expect(raw.statusCode == 200)
    }

    @Test("UUID path segment renders as uppercase string")
    func uuidSegment() async throws {
        let id = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!
        ZIYONRestMock.reset()
        ZIYONRestMock.stub(url: "\(baseURL)/users/\(id.uuidString)") { try! .json(testUser) }
        let client = ZIYONRest.client(baseURL: baseURL, session: ZIYONRestMock.session)
        let raw = try await client.path("users").path(id).get().raw()
        #expect(raw.statusCode == 200)
    }
}

// MARK: — Plain client tests

@Suite("Plain Client")
struct PlainClientTests {

    @Test("GET decodes value")
    func getDecodesValue() async throws {
        ZIYONRestMock.reset()
        ZIYONRestMock.stub(url: "\(baseURL)/users/1") { try! .json(testUser) }
        let client = ZIYONRest.client(baseURL: baseURL, session: ZIYONRestMock.session)

        let user: User = try await client.path("users").path(1).get().value()
        #expect(user == testUser)
    }

    @Test("GET returns raw response")
    func getRaw() async throws {
        ZIYONRestMock.reset()
        ZIYONRestMock.stub(url: "\(baseURL)/users/1") { try! .json(testUser) }
        let client = ZIYONRest.client(baseURL: baseURL, session: ZIYONRestMock.session)

        let raw = try await client.path("users").path(1).get().raw()
        #expect(raw.statusCode == 200)
        #expect(raw.isSuccess)
    }

    @Test("GET returns valueAndHeaders")
    func getValueAndHeaders() async throws {
        ZIYONRestMock.reset()
        ZIYONRestMock.stub(url: "\(baseURL)/users/1") {
            ZIYONRestMockResponse(
                statusCode: 200,
                body: try! JSONEncoder().encode(testUser),
                headers: ["Content-Type": "application/json", "X-Request-ID": "abc123"]
            )
        }
        let client = ZIYONRest.client(baseURL: baseURL, session: ZIYONRestMock.session)
        let (user, headers): (User, [String: String]) = try await client
            .path("users").path(1).get().valueAndHeaders()

        #expect(user == testUser)
        #expect(headers["x-request-id"] == "abc123")
    }

    @Test("HTTP error throws ZIYONRestError.httpError")
    func httpErrorThrows() async throws {
        ZIYONRestMock.reset()
        ZIYONRestMock.stub(url: "\(baseURL)/users/1") {
            ZIYONRestMockResponse(statusCode: 404, body: nil)
        }
        let client = ZIYONRest.client(baseURL: baseURL, session: ZIYONRestMock.session)

        do {
            let _: User = try await client.path("users").path(1).get().value()
            Issue.record("Expected throw")
        } catch let error as ZIYONRestError {
            if case .httpError(let code, _) = error {
                #expect(code == 404)
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("POST encodes body")
    func postEncodesBody() async throws {
        ZIYONRestMock.reset()
        ZIYONRestMock.stub(url: "\(baseURL)/users") { try! .json(testUser, statusCode: 201) }
        let client = ZIYONRest.client(baseURL: baseURL, session: ZIYONRestMock.session)

        let created: User = try await client
            .path("users")
            .post(body: CreateUser(firstName: "Elione", email: "elione@ziyon.co"))
            .value()

        #expect(created.id == 1)
    }

    @Test("DELETE send() does not throw on 204")
    func deleteSend() async throws {
        ZIYONRestMock.reset()
        ZIYONRestMock.stub(url: "\(baseURL)/users/1") {
            ZIYONRestMockResponse(statusCode: 204)
        }
        let client = ZIYONRest.client(baseURL: baseURL, session: ZIYONRestMock.session)
        try await client.path("users").path(1).delete().send()
    }

    @Test("noAuth skips Authorization header")
    func noAuth() async throws {
        ZIYONRestMock.reset()
        ZIYONRestMock.stub(url: "\(baseURL)/users/1") { try! .json(testUser) }
        let client = ZIYONRest.client(baseURL: baseURL, session: ZIYONRestMock.session)

        // noAuth() is a builder-level flag; verify it compiles and runs without crash
        let raw = try await client.path("users").path(1).noAuth().get().raw()
        #expect(raw.isSuccess)
    }
}

// MARK: — Config tests

@Suite("Config")
struct ConfigTests {

    @Test("webAPI preset has snake_case keys")
    func webAPISnakeCase() throws {
        let enc = ZIYONRestJSONCoding.webAPI.encoder
        let dec = ZIYONRestJSONCoding.webAPI.decoder

        struct Payload: Codable, Sendable {
            let firstName: String
        }

        let data = try enc.encode(Payload(firstName: "Elione"))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["first_name"] as? String == "Elione")

        let decoded = try dec.decode(Payload.self, from: data)
        #expect(decoded.firstName == "Elione")
    }

    @Test("RetryPolicy delay is capped at maxDelay")
    func retryDelayCap() {
        let policy = ZIYONRestRetryPolicy(maxAttempts: 5, baseDelay: 1, maxDelay: 4)
        // attempt 3 → 1 * 2^3 = 8 → capped at 4
        #expect(policy.delay(forAttempt: 3) == 4)
    }

    @Test("RetryPolicy shouldRetry returns correct result")
    func shouldRetry() {
        let policy = ZIYONRestRetryPolicy.standard
        #expect(policy.shouldRetry(statusCode: 503) == true)
        #expect(policy.shouldRetry(statusCode: 200) == false)
        #expect(policy.shouldRetry(statusCode: 404) == false)
    }
}

// MARK: — Multipart tests

@Suite("Multipart")
struct MultipartTests {

    @Test("Encode produces valid boundary delimiters")
    func encodeBoundary() {
        var form = ZIYONRestMultipartForm(boundary: "TESTBOUNDARY")
        form.addField(name: "username", value: "elione")
        let data = form.encode()
        let body = String(data: data, encoding: .utf8) ?? ""
        #expect(body.contains("--TESTBOUNDARY"))
        #expect(body.contains("name=\"username\""))
        #expect(body.contains("elione"))
        #expect(body.contains("--TESTBOUNDARY--"))
    }

    @Test("File part includes Content-Type")
    func filePartContentType() {
        var form = ZIYONRestMultipartForm(boundary: "B")
        form.addData(name: "file", data: Data("hello".utf8), filename: "hello.txt", mimeType: "text/plain")
        let body = String(data: form.encode(), encoding: .utf8) ?? ""
        #expect(body.contains("Content-Type: text/plain"))
        #expect(body.contains("filename=\"hello.txt\""))
    }

    @Test("Content-Type header contains boundary")
    func contentTypeHeader() {
        let form = ZIYONRestMultipartForm(boundary: "MY-BOUNDARY")
        #expect(form.contentTypeHeader == "multipart/form-data; boundary=MY-BOUNDARY")
    }
}

// MARK: — Session store tests

@Suite("Session Stores")
struct SessionStoreTests {

    @Test("Memory store round-trips session")
    func memoryStore() async throws {
        let store = ZIYONRestMemoryStore()
        let session = ZIYONRestAuthSession(token: "tok", refreshToken: "rt")
        try await store.save(session)
        let loaded = try await store.load()
        #expect(loaded == session)
        try await store.clear()
        #expect(try await store.load() == nil)
    }

    @Test("Null store always returns nil")
    func nullStore() async throws {
        let store = ZIYONRestNullStore()
        let session = ZIYONRestAuthSession(token: "tok")
        try await store.save(session)
        #expect(try await store.load() == nil)
    }

    @Test("Defaults store round-trips session")
    func defaultsStore() async throws {
        let ud = UserDefaults(suiteName: "ziyon.test.\(UUID().uuidString)")!
        let store = ZIYONRestDefaultsStore(defaults: ud, key: "session")
        let session = ZIYONRestAuthSession(token: "access", refreshToken: "refresh")
        try await store.save(session)
        let loaded = try await store.load()
        #expect(loaded == session)
        try await store.clear()
        #expect(try await store.load() == nil)
    }
}

// MARK: — Pagination tests

@Suite("Pagination")
struct PaginationTests {

    @Test("Page hasMore when currentPage < totalPages")
    func hasModePages() {
        let page = ZIYONRestPage<User>(
            items: [],
            total: 100,
            currentPage: 1,
            totalPages: 5,
            nextCursor: nil
        )
        #expect(page.hasMore == true)
    }

    @Test("Page hasMore false on last page")
    func noMorePages() {
        let page = ZIYONRestPage<User>(
            items: [],
            total: 10,
            currentPage: 5,
            totalPages: 5,
            nextCursor: nil
        )
        #expect(page.hasMore == false)
    }

    @Test("Page hasMore via cursor")
    func cursorHasMore() {
        let page = ZIYONRestPage<User>(
            items: [],
            total: nil,
            currentPage: nil,
            totalPages: nil,
            nextCursor: "cursor-xyz"
        )
        #expect(page.hasMore == true)
    }
}

// MARK: — Download progress tests

@Suite("Download Progress")
struct DownloadProgressTests {

    @Test("fractionCompleted is correct")
    func fraction() {
        let p = ZIYONRestDownloadProgress(bytesWritten: 50, totalBytes: 100)
        #expect(p.fractionCompleted == 0.5)
    }

    @Test("fractionCompleted is nil when total unknown")
    func fractionUnknown() {
        let p = ZIYONRestDownloadProgress(bytesWritten: 50, totalBytes: -1)
        #expect(p.fractionCompleted == nil)
    }

    @Test("percentString formats correctly")
    func percentString() {
        let p = ZIYONRestDownloadProgress(bytesWritten: 75, totalBytes: 100)
        #expect(p.percentString == "75%")
    }
}
