import Foundation
import SiteIcons
import Synchronization
import Testing

private final class Clock: Sendable {
    let date = Mutex(Date())
    var now: @Sendable () -> Date { { self.date.withLock { $0 } } }
    func advance(_ seconds: TimeInterval) { date.withLock { $0 += seconds } }
}

@Suite struct SiteIconCacheTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "site-icons-\(UUID().uuidString)")

    private func cache(_ clock: Clock) -> SiteIconCache {
        SiteIconCache(directory: directory, negativeLifetime: 7 * 86_400, legacyLifetime: 30 * 86_400, now: clock.now)
    }

    @Test func anIconIsFreshUntilItsLifetimeThenExpiredButStillServed() throws {
        let clock = Clock()
        try cache(clock).writeIcon(try iconImage(size: 32), key: "apple.com", lifetime: 3_600)
        guard case .icon(let image, let expired)? = cache(clock).read("apple.com") else { Issue.record("no icon"); return }
        #expect(image.width == 32 && !expired)
        clock.advance(3_600)
        guard case .icon(_, true)? = cache(clock).read("apple.com") else { Issue.record("not expired"); return }
        try cache(clock).extend("apple.com", lifetime: 60)
        guard case .icon(_, false)? = cache(clock).read("apple.com") else { Issue.record("not extended"); return }
    }

    @Test func aNegativeMarkerHoldsForItsLifetimeThenGoes() throws {
        let clock = Clock()
        try cache(clock).writeMissing("example.org")
        guard case .missing? = cache(clock).read("example.org") else { Issue.record("no marker"); return }
        clock.advance(7 * 86_400 - 5)
        guard case .missing? = cache(clock).read("example.org") else { Issue.record("expired early"); return }
        // The marker's date is the file system's, a few milliseconds after the clock started.
        clock.advance(10)
        let marker = cache(clock).fileURL(for: "example.org", extension: "none")
        #expect(cache(clock).read("example.org") == nil)
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }

    @Test func anEmptyMarkerFromAnOlderVersionIsIgnoredAndRemoved() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let marker = cache(Clock()).fileURL(for: "old.example", extension: "none")
        try Data().write(to: marker)
        #expect(cache(Clock()).read("old.example") == nil)
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }

    @Test func anIconWrittenBeforeExpiriesCountsFromItsFileDate() throws {
        let clock = Clock()
        try cache(clock).writeIcon(try iconImage(size: 16), key: "legacy.example", lifetime: 1)
        try FileManager.default.removeItem(at: cache(clock).fileURL(for: "legacy.example", extension: "expires"))
        let icon = cache(clock).fileURL(for: "legacy.example", extension: "png")
        try FileManager.default.setAttributes([.modificationDate: clock.now()], ofItemAtPath: icon.path)
        #expect(cache(clock).expiry("legacy.example") == clock.now().addingTimeInterval(30 * 86_400))
    }

    @Test func writingAnIconClearsTheNegativeMarker() throws {
        let clock = Clock()
        try cache(clock).writeMissing("example.org")
        try cache(clock).writeIcon(try iconImage(size: 16), key: "example.org", lifetime: 60)
        #expect(!FileManager.default.fileExists(atPath: cache(clock).fileURL(for: "example.org", extension: "none").path))
    }

    @Test func aDomainIsItsOwnFileNameAndAnOriginIsEncoded() {
        let cache = cache(Clock())
        #expect(cache.fileURL(for: "apple.com", extension: "png").lastPathComponent == "apple.com.png")
        #expect(cache.fileURL(for: "https://a.example:8443", extension: "png").lastPathComponent == "https%3A%2F%2Fa.example%3A8443.png")
        #expect(cache.fileURL(for: "..", extension: "png").lastPathComponent == "%2E..png")
    }
}

@Suite struct IconLifetimeTests {
    private let bounds = IconLifetime(minimum: 86_400, maximum: 90 * 86_400, fallback: 30 * 86_400)

    @Test func maxAgeGivesTheLifetimeWithinTheBounds() {
        #expect(bounds.lifetime(cacheControl: "public, max-age=604800") == 604_800)
        #expect(bounds.lifetime(cacheControl: "max-age=60") == 86_400)
        #expect(bounds.lifetime(cacheControl: "max-age=31536000, immutable") == 90 * 86_400)
        #expect(bounds.lifetime(cacheControl: #"MAX-AGE="172800""#) == 172_800)
    }

    @Test func noStoreAndNoCacheGiveTheMinimum() {
        #expect(bounds.lifetime(cacheControl: "no-store") == 86_400)
        #expect(bounds.lifetime(cacheControl: "max-age=604800, no-cache") == 86_400)
    }

    @Test func noExplicitLifetimeGivesTheFallback() {
        #expect(bounds.lifetime(cacheControl: nil) == 30 * 86_400)
        #expect(bounds.lifetime(cacheControl: "public") == 30 * 86_400)
        #expect(bounds.lifetime(cacheControl: "s-maxage=60") == 30 * 86_400)
        #expect(bounds.lifetime(cacheControl: "max-age=soon") == 30 * 86_400)
        #expect(bounds.lifetime(cacheControl: "max-age=-5") == 30 * 86_400)
    }
}
