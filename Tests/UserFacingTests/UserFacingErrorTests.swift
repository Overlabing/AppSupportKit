import Foundation
import Testing
import UserFacing

@Suite struct UserFacingErrorTests {
    private struct ProviderError: CancellationReporting {
        var isCancellation: Bool
    }

    private struct Shown: UserFacingErrorConvertible {
        var userFacingError: UserFacingError { UserFacingError(title: "t", message: "m") }
    }

    @Test("A cancellation is never shown: Swift, URL loading, an app error that says so, Cocoa")
    func cancellationsAreNotErrors() {
        #expect(UserFacingError.isCancellation(CancellationError()))
        #expect(UserFacingError.isCancellation(URLError(.cancelled)))
        #expect(UserFacingError.isCancellation(ProviderError(isCancellation: true)))
        #expect(UserFacingError.isCancellation(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)))
        #expect(UserFacingError.isCancellation(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
        #expect(!UserFacingError.isCancellation(URLError(.timedOut)))
        #expect(!UserFacingError.isCancellation(ProviderError(isCancellation: false)))
        #expect(!UserFacingError.isCancellation(Shown()))
    }

    @Test("A message that points to the details has details to copy, never an empty promise")
    func detailsAreCopiedWithTheTitle() {
        let error = UserFacingError(title: "t", message: "m", technicalDetail: "451 : try later")
        #expect(error.canCopyDetails)
        #expect(error.copiedDetails == "t\n\nm\n\n451 : try later")
        #expect(!UserFacingError(title: "t", message: "m", technicalDetail: "").canCopyDetails)
        #expect(!UserFacingError(title: "t", message: "m").canCopyDetails)
        #expect(UserFacingError(title: "t", message: "m").copiedDetails == "t\n\nm")
    }

    @Test("An alert by default, with the generic symbol")
    func defaults() {
        let error = UserFacingError(title: "t", message: "m")
        #expect(error.presentation == .alert)
        #expect(error.symbol == "exclamationmark.triangle")
        #expect(error.action == nil)
        #expect(UserFacingError.Symbol.offline == "wifi.slash")
        #expect(UserFacingError.Symbol.hostNotFound == "network.slash")
        #expect(UserFacingError.Symbol.waiting == "hourglass")
        #expect(UserFacingError.Symbol.certificate == "lock.trianglebadge.exclamationmark")
    }

    @Test("Only an action that opens a page has a URL; each keeps the title the app gave")
    func actionsCarryTheirTitleAndURL() {
        let page = URL(string: "https://account.apple.com/account/manage")!
        #expect(UserFacingError.Action.openURL(page, title: "Open").url == page)
        #expect(UserFacingError.Action.openURL(page, title: "Open").title == "Open")
        #expect(UserFacingError.Action.openSettings(pane: "accounts", title: "Open Settings").url == nil)
        #expect(UserFacingError.Action.openSettings(pane: "accounts", title: "Open Settings").title == "Open Settings")
        #expect(UserFacingError.Action.custom(id: "export", title: "Export").title == "Export")
        #expect(UserFacingError.Action.retry.url == nil)
    }

    /// `check.sh` pins French, then English (`OVERLABING_TEST_LANGUAGE`).
    @Test func tryAgainSpeaksThePinnedLanguage() {
        let expected = ["fr": "Réessayer", "en": "Try Again"]
        let pinned = ProcessInfo.processInfo.environment["OVERLABING_TEST_LANGUAGE"] ?? ""
        #expect(UserFacingError.Action.retry.title == expected[pinned] ?? UserFacingError.Action.retry.title)
        #expect(!UserFacingError.Action.retry.title.isEmpty)
    }

    @Test("An unknown error keeps its own description, and its reflection goes to the details")
    func theCatchAllKeepsTheDescription() {
        let underlying = NSError(domain: "Test", code: 7, userInfo: [NSLocalizedDescriptionKey: "Disk full."])
        let error = UserFacingError(unexpected: underlying)
        #expect(error.message == "Disk full.")
        #expect(error.technicalDetail == String(reflecting: underlying))
        #expect(error.presentation == .alert)
        #expect(error.action == nil)
    }
}
