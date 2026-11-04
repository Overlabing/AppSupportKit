import Foundation

/// How long a fetched icon stays fresh, read from its `Cache-Control` response header (RFC 9111) and kept within the
/// app's bounds: `max-age` (§5.2.2.1) gives the lifetime; `no-cache` (§5.2.2.4) and `no-store` (§5.2.2.5) give the
/// minimum, since an icon kept for no time would be asked for at every launch; no explicit lifetime gives the app's
/// heuristic `fallback` (§4.2.2). `s-maxage` applies to shared caches only, and this cache is private.
public struct IconLifetime: Sendable, Equatable {
    public var minimum: TimeInterval
    public var maximum: TimeInterval
    public var fallback: TimeInterval

    public init(minimum: TimeInterval, maximum: TimeInterval, fallback: TimeInterval) {
        self.minimum = minimum
        self.maximum = max(minimum, maximum)
        self.fallback = fallback
    }

    public func lifetime(cacheControl: String?) -> TimeInterval {
        let directives = Self.directives(cacheControl)
        let seconds: TimeInterval
        if directives["no-store"] != nil || directives["no-cache"] != nil {
            seconds = minimum
        } else if let maxAge = directives["max-age"].flatMap({ $0 }).flatMap(TimeInterval.init), maxAge >= 0 {
            seconds = maxAge
        } else {
            seconds = fallback
        }
        return min(max(seconds, minimum), maximum)
    }

    /// Directive names lowercased, each with its argument, quotes removed; a repeated directive keeps its first value.
    static func directives(_ header: String?) -> [String: String?] {
        var result: [String: String?] = [:]
        for part in (header ?? "").split(separator: ",") {
            let pieces = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard let name = pieces.first?.lowercased(), !name.isEmpty, result[name] == nil else { continue }
            result[name] = pieces.count == 2 ? pieces[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"")) : nil
        }
        return result
    }
}
