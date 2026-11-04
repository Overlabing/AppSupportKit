import Foundation

/// One image to try, in the order `IconDiscovery.candidates` gives.
public struct IconCandidate: Sendable, Hashable {
    public var url: URL
    /// The colour a `mask-icon` is filled with (`#rrggbb`), nil for a full-colour icon.
    public var maskColor: String?

    public init(url: URL, maskColor: String? = nil) {
        self.url = url
        self.maskColor = maskColor
    }
}

/// The icon links of a page, each list in the order `IconDiscovery` tries it.
public struct IconPageLinks: Sendable, Equatable {
    /// `<link rel=manifest>` (HTML §4.6.8.11): the web app manifest, whose icons come first.
    public var manifest: URL?
    /// `<link rel=apple-touch-icon(-precomposed)>`, largest first.
    public var touchIcons: [URL]
    /// `<link rel=icon>` (HTML §4.6.8.9, `shortcut icon` included), largest first.
    public var icons: [URL]
    /// `<link rel=mask-icon color=…>`: a one-colour SVG filled with its `color` (HTML §4.2.4, the `color` attribute).
    public var maskIcons: [IconCandidate]

    public init(manifest: URL? = nil, touchIcons: [URL] = [], icons: [URL] = [], maskIcons: [IconCandidate] = []) {
        self.manifest = manifest
        self.touchIcons = touchIcons
        self.icons = icons
        self.maskIcons = maskIcons
    }
}

/// Finds a site's icons in a document the app already has, and ranks them. The kit never fetches anything: the app
/// gives the page (or the links it read from a loaded page), then the manifest if it wants its icons, and fetches the
/// candidates itself.
///
/// Every URL is resolved against the document base URL (HTML §2.4.3, document base URLs: the first `<base href>`, else
/// the document's URL) or, for a manifest's icons, against the manifest URL (Web App Manifest §1.7, `icons` member, and
/// §2.5, processing image resources). Only `https` URLs of the site or one of its subdomains are kept, and `data:` URLs
/// of an image type (RFC 2397), which need no request: never a third-party CDN.
public enum IconDiscovery {
    /// The paths tried on the site after its links, in order: the first that decodes wins.
    public static let defaultPaths = ["/apple-touch-icon.png", "/favicon.ico"]

    /// Image types the decoder reads (`SiteIconDecoder`). A link or a manifest icon that declares another type is
    /// skipped without a request (HTML §4.6.8.9: a user agent does not fetch an icon whose type it does not support).
    public static let imageTypes: Set<String> = [
        "image/png", "image/svg+xml", "image/x-icon", "image/vnd.microsoft.icon", "image/ico", "image/jpeg", "image/jpg",
        "image/webp", "image/gif",
    ]
    private static let imageExtensions: Set<String> = ["png", "svg", "ico", "jpg", "jpeg", "webp", "gif", ""]

    /// A URL allowed for `site`: `https` on `site` or one of its subdomains, or a `data:` URL of an image type.
    public static func isAllowed(_ url: URL, site: String) -> Bool {
        if url.scheme?.lowercased() == "data" { return DataURL(url).map { imageTypes.contains($0.mediaType) } ?? false }
        guard url.scheme?.lowercased() == "https", let host = url.host()?.lowercased() else { return false }
        return host == site || host.hasSuffix("." + site)
    }

    /// The icon links of `html`, a page served at `page`, kept for `site`.
    public static func links(inHTML html: String, page: URL, site: String) -> IconPageLinks {
        let tags = HTMLLinkScanner.scan(html)
        let base = tags.baseHref.flatMap { URL(string: $0.trimmingCharacters(in: .whitespacesAndNewlines), relativeTo: page) }
        return links(fromTags: tags.links, base: base?.absoluteURL ?? page, site: site)
    }

    /// The icon links among `tags`, the attributes of each `<link>` (names lowercased) that an app read from a loaded
    /// page, resolved against the document base URL `base`.
    public static func links(fromTags tags: [[String: String]], base: URL, site: String) -> IconPageLinks {
        var links = IconPageLinks()
        var touch: [(URL, Int)] = []
        var icons: [(URL, Int)] = []
        for attributes in tags {
            guard let href = attributes["href"],
                let url = URL(string: href.trimmingCharacters(in: .whitespacesAndNewlines), relativeTo: base)?.absoluteURL,
                isAllowed(url, site: site)
            else { continue }
            // `rel` is an unordered set of unique space-separated tokens, ASCII case-insensitive (HTML §4.2.4, §4.6.8).
            let rel = Set((attributes["rel"] ?? "").lowercased().split(whereSeparator: \.isWhitespace).map(String.init))
            if let type = attributes["type"], !type.isEmpty, !imageTypes.contains(mediaType(type)) { continue }
            let size = largestSize(attributes["sizes"])
            if rel.contains("manifest") {
                if links.manifest == nil { links.manifest = url }
            } else if rel.contains("apple-touch-icon") || rel.contains("apple-touch-icon-precomposed") {
                touch.append((url, size))
            } else if rel.contains("icon") {
                icons.append((url, size))
            } else if rel.contains("mask-icon") {
                links.maskIcons.append(IconCandidate(url: url, maskColor: attributes["color"].flatMap(hexColor)))
            }
        }
        links.touchIcons = largestFirst(touch)
        links.icons = largestFirst(icons)
        return links
    }

    /// The icons of a web app manifest served at `manifest`, kept for `site`: `purpose` "any" (or absent) first, then
    /// "maskable", each largest first; a "monochrome"-only icon, or one whose purposes are all unknown, is skipped (Web
    /// App Manifest §2.1, `purpose` member). Image types only. Empty when the JSON is invalid.
    public static func manifestIcons(_ data: Data, manifest: URL, site: String) -> [URL] {
        struct Manifest: Decodable {
            struct Icon: Decodable {
                var src: String?
                var sizes: String?
                var type: String?
                var purpose: String?
            }
            var icons: [Icon]?
        }
        let decoded: Manifest
        do {
            decoded = try JSONDecoder().decode(Manifest.self, from: data)
        } catch {
            return []
        }
        var any: [(URL, Int)] = []
        var maskable: [(URL, Int)] = []
        for icon in decoded.icons ?? [] {
            guard let src = icon.src, let url = URL(string: src, relativeTo: manifest)?.absoluteURL,
                isAllowed(url, site: site), isImage(type: icon.type, url: url)
            else { continue }
            let purposes = Set((icon.purpose ?? "any").lowercased().split(whereSeparator: \.isWhitespace).map(String.init))
            let size = largestSize(icon.sizes)
            if purposes.contains("any") {
                any.append((url, size))
            } else if purposes.contains("maskable") {
                maskable.append((url, size))
            }
        }
        return largestFirst(any) + largestFirst(maskable)
    }

    /// Every image to try for a site, in order, at most `limit`: the manifest's icons, the touch icons, the icons, the
    /// default paths on `origin` (`https://host`), then the mask icons, which are one colour. Each URL once.
    public static func candidates(
        _ links: IconPageLinks, manifestIcons: [URL] = [], origin: String, defaultPaths: [String] = defaultPaths, limit: Int
    ) -> [IconCandidate] {
        let full = (manifestIcons + links.touchIcons + links.icons + defaultPaths.compactMap { URL(string: "https://\(origin)\($0)") })
            .map { IconCandidate(url: $0) }
        var seen: Set<URL> = []
        return Array((full + links.maskIcons).filter { seen.insert($0.url).inserted }.prefix(limit))
    }

    /// The largest side in `sizes` ("16x16 32x32" → 32); "any" (a scalable image) comes before every size; none: 0.
    public static func largestSize(_ sizes: String?) -> Int {
        guard let sizes else { return 0 }
        return sizes.lowercased().split(whereSeparator: \.isWhitespace).map { token -> Int in
            if token == "any" { return Int.max }
            let sides = token.split(separator: "x").compactMap { Int($0) }
            return sides.count == 2 ? max(sides[0], sides[1]) : 0
        }.max() ?? 0
    }

    private static func largestFirst(_ candidates: [(URL, Int)]) -> [URL] {
        var seen: Set<URL> = []
        return candidates.enumerated()
            .sorted { ($0.element.1, -$0.offset) > ($1.element.1, -$1.offset) }
            .map(\.element.0)
            .filter { seen.insert($0).inserted }
    }

    private static func isImage(type: String?, url: URL) -> Bool {
        if let type { return imageTypes.contains(mediaType(type)) }
        if url.scheme?.lowercased() == "data" { return true }
        return imageExtensions.contains(url.pathExtension.lowercased())
    }

    /// `image/png; charset=…` → `image/png`.
    static func mediaType(_ type: String) -> String {
        String(type.split(separator: ";").first ?? "").trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// `#rgb` or `#rrggbb`, lowercased and expanded; nil for any other colour syntax.
    static func hexColor(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard value.hasPrefix("#"), value.dropFirst().allSatisfy(\.isHexDigit) else { return nil }
        switch value.count {
        case 7: return value
        case 4: return "#" + value.dropFirst().map { "\($0)\($0)" }.joined()
        default: return nil
        }
    }
}
