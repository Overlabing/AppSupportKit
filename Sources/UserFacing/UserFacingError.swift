import Foundation

/// An error as the user reads it: what happened (a short title), what to do (the message), the raw text of the server or
/// the system kept apart (technical detail, folded away in the interface, never a title) and, when it helps, one action.
/// Each app builds its own catalogue of errors on top of this core, with `UserFacingErrorConvertible` and extensions.
public struct UserFacingError: Error, Sendable, Hashable {
    /// Where the app shows it outside a form: in a banner (it goes away by itself, such as a network failure the app
    /// retries) or in an alert.
    public enum Presentation: Sendable, Hashable {
        case banner
        case alert
    }

    /// The button that comes with the message. Titles are verbs (HIG: Alerts, Writing).
    public enum Action: Sendable, Hashable {
        /// Run again what failed.
        case retry
        /// Open a web page in the browser. The URL is the app's, never one taken unchecked from a network reply.
        case openURL(URL, title: String)
        /// Open a pane of the app's settings, named as the app names its panes.
        case openSettings(pane: String, title: String)
        /// Anything else the app handles itself, by identifier.
        case custom(id: String, title: String)

        public var title: String {
            switch self {
            case .retry: localized("Try Again")
            case .openURL(_, let title), .openSettings(_, let title), .custom(_, let title): title
            }
        }

        /// The page to open, nil for every action that stays in the app.
        public var url: URL? {
            if case .openURL(let url, _) = self { return url }
            return nil
        }
    }

    public var title: String
    public var message: String
    /// The raw text of the server or the error, most often in English: folded away ("Technical details") and logged as
    /// private, never a title.
    public var technicalDetail: String?
    public var action: Action?
    public var presentation: Presentation
    /// The SF Symbol of the banner, after the nature of the failure (`Symbol`).
    public var symbol: String

    public init(
        title: String, message: String, technicalDetail: String? = nil, action: Action? = nil,
        presentation: Presentation = .alert, symbol: String = Symbol.problem
    ) {
        self.title = title
        self.message = message
        self.technicalDetail = technicalDetail
        self.action = action
        self.presentation = presentation
        self.symbol = symbol
    }

    /// The SF Symbols of errors, shared by banners: a problem, offline, a host not found, waiting, a refused certificate.
    public enum Symbol {
        public static let problem = "exclamationmark.triangle"
        public static let offline = "wifi.slash"
        public static let hostNotFound = "network.slash"
        public static let waiting = "hourglass"
        public static let certificate = "lock.trianglebadge.exclamationmark"
    }

    /// The alert offers "Copy Details": an alert does not show the technical detail, so a message never points to it
    /// without that button.
    public var canCopyDetails: Bool { technicalDetail.map { !$0.isEmpty } ?? false }

    /// What "Copy Details" puts on the pasteboard: title, message and technical detail.
    public var copiedDetails: String {
        [title, message, technicalDetail].compactMap { $0 }.joined(separator: "\n\n")
    }

    /// The catch-all of a catalogue: an error nothing more precise describes. Its own description is the message, its
    /// full reflection the technical detail.
    public init(unexpected error: any Error) {
        self.init(
            title: localized("The action didn't complete"), message: error.localizedDescription,
            technicalDetail: String(reflecting: error))
    }
}

/// An app error that knows how it is shown.
public protocol UserFacingErrorConvertible: Error {
    var userFacingError: UserFacingError { get }
}

/// An app error that can stand for a cancellation, such as a request a provider dropped because its caller left.
public protocol CancellationReporting: Error {
    var isCancellation: Bool { get }
}

extension UserFacingError {
    /// A cancelled operation (selection changed, view gone, fetch superseded) is never an error for the user: no alert,
    /// no banner. Covers Swift concurrency, URL loading, Cocoa's user cancellation and every `CancellationReporting`
    /// error that says so.
    public static func isCancellation(_ error: any Error) -> Bool {
        if error is CancellationError { return true }
        if (error as? URLError)?.code == .cancelled { return true }
        if (error as? any CancellationReporting)?.isCancellation == true { return true }
        let ns = error as NSError
        return (ns.domain == NSCocoaErrorDomain && ns.code == NSUserCancelledError)
            || (ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled)
    }
}
