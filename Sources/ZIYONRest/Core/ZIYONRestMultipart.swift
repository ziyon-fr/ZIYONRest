// ZIYONRestMultipart.swift
// ZIYON SAS — Swift 6 REST Client

import Foundation

// MARK: — Multipart form-data

/// Builds a `multipart/form-data` body for file upload or mixed-field requests.
///
/// ```swift
/// var form = ZIYONRestMultipartForm()
/// form.addField(name: "username", value: "elione")
/// form.addData(name: "avatar", data: jpegData, filename: "avatar.jpg", mimeType: "image/jpeg")
///
/// var req = try client.path("v1/upload").post()
/// // inject body + content-type header manually when using multipart
/// ```
public struct ZIYONRestMultipartForm: Sendable {

    // MARK: Part

    public struct Part: Sendable {
        let name: String
        let filename: String?
        let mimeType: String?
        let data: Data
    }

    // MARK: State

    private var parts: [Part] = []

    /// The multipart boundary string.
    public let boundary: String

    public init(boundary: String = "ZIYONRest.\(UUID().uuidString)") {
        self.boundary = boundary
    }

    // MARK: Additions

    /// Adds a plain text field.
    public mutating func addField(name: String, value: String) {
        let data = Data(value.utf8)
        parts.append(Part(name: name, filename: nil, mimeType: nil, data: data))
    }

    /// Adds raw bytes as a file part.
    public mutating func addData(
        name: String,
        data: Data,
        filename: String,
        mimeType: String = "application/octet-stream"
    ) {
        parts.append(Part(name: name, filename: filename, mimeType: mimeType, data: data))
    }

    // MARK: Build

    /// Encodes the form body.
    public func encode() -> Data {
        var body = Data()
        let crlf = "\r\n"
        let dash = "--"

        for part in parts {
            body.append(Data("\(dash)\(boundary)\(crlf)".utf8))

            var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
            if let fname = part.filename {
                disposition += "; filename=\"\(fname)\""
            }
            body.append(Data("\(disposition)\(crlf)".utf8))

            if let mime = part.mimeType {
                body.append(Data("Content-Type: \(mime)\(crlf)".utf8))
            }

            body.append(Data(crlf.utf8))
            body.append(part.data)
            body.append(Data(crlf.utf8))
        }

        body.append(Data("\(dash)\(boundary)\(dash)\(crlf)".utf8))
        return body
    }

    /// The value to set as the `Content-Type` header.
    public var contentTypeHeader: String {
        "multipart/form-data; boundary=\(boundary)"
    }
}

// MARK: — Builder extension for multipart

extension ZIYONRestRequestBuilder {
    /// Configures a POST request with a multipart form body.
    public func post(multipart form: ZIYONRestMultipartForm) -> ZIYONRestPendingRequest {
        var copy = self
        copy.context.method = .post
        copy.context.body = form.encode()
        copy.context.headers["Content-Type"] = form.contentTypeHeader
        return ZIYONRestPendingRequest(builder: copy)
    }

    /// Configures a PUT request with a multipart form body.
    public func put(multipart form: ZIYONRestMultipartForm) -> ZIYONRestPendingRequest {
        var copy = self
        copy.context.method = .put
        copy.context.body = form.encode()
        copy.context.headers["Content-Type"] = form.contentTypeHeader
        return ZIYONRestPendingRequest(builder: copy)
    }
}

extension ZIYONRestAuthRequestBuilder {
    /// Configures a POST request with a multipart form body.
    public func post(multipart form: ZIYONRestMultipartForm) -> ZIYONRestAuthPendingRequest {
        var copy = self
        copy.context.method = .post
        copy.context.body = form.encode()
        copy.context.headers["Content-Type"] = form.contentTypeHeader
        return ZIYONRestAuthPendingRequest(builder: copy)
    }

    /// Configures a PUT request with a multipart form body.
    public func put(multipart form: ZIYONRestMultipartForm) -> ZIYONRestAuthPendingRequest {
        var copy = self
        copy.context.method = .put
        copy.context.body = form.encode()
        copy.context.headers["Content-Type"] = form.contentTypeHeader
        return ZIYONRestAuthPendingRequest(builder: copy)
    }
}
