import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The icons of sites on disk, under a key the app chooses (a registrable domain, a page origin): the kit never
/// computes one. Each key holds an icon (`<key>.png`, with its expiry in `<key>.expires`) or a negative marker
/// (`<key>.none`), which says the site answered without a usable icon and holds for `negativeLifetime`.
///
/// Writing is the app's choice: a failure to write leaves the icon in memory and is the app's to log.
public struct SiteIconCache: Sendable {
    public enum Entry: Sendable {
        /// The icon, and whether its lifetime is over: still shown, and fetched again.
        case icon(CGImage, isExpired: Bool)
        /// The site has no usable icon, for now.
        case missing
    }

    public let directory: URL
    public let negativeLifetime: TimeInterval
    /// The lifetime of an icon written before expiries were kept, counted from its file's date.
    public let legacyLifetime: TimeInterval
    private let now: @Sendable () -> Date

    public init(
        directory: URL, negativeLifetime: TimeInterval, legacyLifetime: TimeInterval,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.directory = directory
        self.negativeLifetime = negativeLifetime
        self.legacyLifetime = legacyLifetime
        self.now = now
    }

    /// The file of `key` with this extension: an app keeps its own markers next to the cache's (`unreachable`, say).
    /// A key made only of lowercase letters, digits, dots and hyphens (a domain) is the file name as is; any other
    /// character is percent-encoded, so that an origin such as `https://a.example:8443` makes one safe file name.
    public func fileURL(for key: String, extension pathExtension: String) -> URL {
        directory.appending(path: "\(Self.fileName(key)).\(pathExtension)")
    }

    static func fileName(_ key: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-")
        let name = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
        return name.hasPrefix(".") ? "%2E" + name.dropFirst() : name
    }

    /// The icon or the current negative marker of `key`; nil when there is neither. A negative marker past its
    /// lifetime, or an empty one, is removed.
    public func read(_ key: String) -> Entry? {
        if let source = CGImageSourceCreateWithURL(fileURL(for: key, extension: "png") as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        {
            return .icon(image, isExpired: expiry(key).map { $0 <= now() } ?? false)
        }
        let marker = fileURL(for: key, extension: "none")
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: marker.path),
            let written = attributes[.modificationDate] as? Date
        else { return nil }
        let isCurrent = (attributes[.size] as? Int ?? 0) > 0
        if isCurrent, now().timeIntervalSince(written) < negativeLifetime { return .missing }
        // A failed removal changes nothing: the marker is read as expired again, or written again.
        try? FileManager.default.removeItem(at: marker)
        return nil
    }

    /// When the icon of `key` expires: its `expires` file, else its file's date plus `legacyLifetime`.
    public func expiry(_ key: String) -> Date? {
        if let data = try? Data(contentsOf: fileURL(for: key, extension: "expires")),
            let seconds = Double(String(decoding: data, as: UTF8.self))
        {
            return Date(timeIntervalSinceReferenceDate: seconds)
        }
        let icon = fileURL(for: key, extension: "png")
        let written = (try? FileManager.default.attributesOfItem(atPath: icon.path))?[.modificationDate] as? Date
        return written?.addingTimeInterval(legacyLifetime)
    }

    /// Writes the icon as PNG with its lifetime, and removes a negative marker.
    public func writeIcon(_ image: CGImage, key: String, lifetime: TimeInterval) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(
            fileURL(for: key, extension: "png") as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        try writeExpiry(key, lifetime: lifetime)
        try? FileManager.default.removeItem(at: fileURL(for: key, extension: "none"))
    }

    /// Keeps the icon of `key` for `lifetime` more, when a new attempt found nothing better.
    public func extend(_ key: String, lifetime: TimeInterval) throws {
        try writeExpiry(key, lifetime: lifetime)
    }

    /// Marks `key` as having no usable icon. The marker has contents: an empty one, from older versions, is ignored.
    public func writeMissing(_ key: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("1".utf8).write(to: fileURL(for: key, extension: "none"), options: .atomic)
    }

    private func writeExpiry(_ key: String, lifetime: TimeInterval) throws {
        // The reference date is what `Date` stores: it reads back exactly, the 1970 one loses a bit on the way.
        let expiry = now().addingTimeInterval(lifetime).timeIntervalSinceReferenceDate
        try Data(String(expiry).utf8).write(to: fileURL(for: key, extension: "expires"), options: .atomic)
    }
}
