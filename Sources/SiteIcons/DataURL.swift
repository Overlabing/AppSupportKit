import Foundation

/// A `data:` URL (RFC 2397): `data:[<mediatype>][;base64],<data>`. An icon given this way needs no request.
public struct DataURL: Sendable, Equatable {
    /// The media type without parameters, lowercased; `text/plain` when absent (RFC 2397 §2).
    public var mediaType: String
    public var data: Data

    /// Nil when `url` is not a `data:` URL, cannot be decoded, or its data is longer than `limit` bytes.
    public init?(_ url: URL, limit: Int = .max) {
        let text = url.absoluteString
        guard text.lowercased().hasPrefix("data:"), let comma = text.firstIndex(of: ",") else { return nil }
        let header = text[text.index(text.startIndex, offsetBy: 5)..<comma]
        let parameters = header.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
        let isBase64 = parameters.dropFirst().contains { $0.lowercased() == "base64" }
        let type = parameters.first.map { $0.trimmingCharacters(in: .whitespaces).lowercased() } ?? ""
        let payload = String(text[text.index(after: comma)...])
        guard payload.utf8.count <= limit.multipliedReportingOverflow(by: 3).partialValue else { return nil }
        let decoded: Data?
        if isBase64 {
            decoded = Data(base64Encoded: payload.removingPercentEncoding ?? payload, options: .ignoreUnknownCharacters)
        } else {
            decoded = payload.removingPercentEncoding.map { Data($0.utf8) }
        }
        guard let decoded, decoded.count <= limit else { return nil }
        mediaType = type.isEmpty ? "text/plain" : type
        data = decoded
    }
}
