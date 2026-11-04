import Foundation
import Synchronization
import UniformTypeIdentifiers

/// An installed app, as LaunchServices gives it.
public struct InstalledApplication: Sendable, Hashable {
    public var url: URL
    public var bundleIdentifier: String?
    /// The name shown in the Finder, without `.app`.
    public var name: String

    public init(url: URL, bundleIdentifier: String?, name: String) {
        self.url = url
        self.bundleIdentifier = bundleIdentifier
        self.name = name
    }
}

/// What an app asks of LaunchServices about default apps: `WorkspaceDefaultApplications` on the Mac, simulated in tests
/// and demos (`SimulatedDefaultApplications`).
public protocol DefaultApplicationClient: Sendable {
    /// The default app for this URL scheme (`mailto`, `https`), nil when there is none.
    func defaultApplication(forScheme scheme: String) async -> InstalledApplication?
    /// The default app for this content type (`public.html`), nil when there is none.
    func defaultApplication(forContentType type: UTType) async -> InstalledApplication?
    /// Where the app with this bundle identifier is installed, nil when it is not.
    func applicationURL(bundleIdentifier: String) async -> URL?
    /// Launches the app, or brings it to the front when it is running.
    func openApplication(at url: URL) async throws
    /// Makes the app at `url` the default for the scheme. The system asks the user to confirm. A sandboxed app cannot
    /// do it: the call fails, and the app sends the user where the setting lives instead.
    func makeDefault(_ url: URL, forScheme scheme: String) async throws
}

/// Is this app the default for a scheme?
public enum DefaultApplicationStatus: Sendable, Hashable {
    case thisApp
    /// Another app is (its name).
    case other(String)
    /// No app is.
    case none
    /// Not read yet.
    case unknown

    public var isThisApp: Bool { self == .thisApp }
}

/// Reads whether this app is the default for a scheme. Another copy of the same app (a Debug build next to the installed
/// one) counts as this app: LaunchServices picks the copy, the user sees one app. Nothing is read by itself: the app reads
/// the status when its setting appears and when it comes back to the foreground, since the user changes the default
/// elsewhere in between.
public struct DefaultApplicationCheck: Sendable {
    public let client: any DefaultApplicationClient
    private let applicationURL: URL
    private let bundleIdentifier: String

    /// - Parameters:
    ///   - applicationURL: the bundle of the running app (`Bundle.main.bundleURL`).
    ///   - bundleIdentifier: its bundle identifier.
    public init(client: any DefaultApplicationClient, applicationURL: URL, bundleIdentifier: String) {
        self.client = client
        self.applicationURL = applicationURL
        self.bundleIdentifier = bundleIdentifier
    }

    public func status(forScheme scheme: String) async -> DefaultApplicationStatus {
        guard let app = await client.defaultApplication(forScheme: scheme) else { return .none }
        if app.bundleIdentifier?.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
            || app.url.standardizedFileURL == applicationURL.standardizedFileURL
        {
            return .thisApp
        }
        return .other(app.name)
    }

    /// Makes this app the default for the scheme (see `DefaultApplicationClient.makeDefault`).
    public func makeDefault(forScheme scheme: String) async throws {
        try await client.makeDefault(applicationURL, forScheme: scheme)
    }
}

/// LaunchServices simulated: tests, and demos, where a capture or a click never opens anything on the Mac.
public final class SimulatedDefaultApplications: DefaultApplicationClient {
    private let state: Mutex<State>

    fileprivate struct State {
        var defaults: [String: InstalledApplication]
        var contentTypes: [String: InstalledApplication]
        var installed: [String: URL]
        var opened: [URL] = []
        var failure: (any Error & Sendable)?
    }

    /// - Parameters:
    ///   - defaults: the default app of each scheme.
    ///   - contentTypes: the default app of each content type, by identifier.
    ///   - installed: where each bundle identifier is installed.
    public init(
        defaults: [String: InstalledApplication] = [:], contentTypes: [String: InstalledApplication] = [:],
        installed: [String: URL] = [:]
    ) {
        state = Mutex(State(defaults: defaults, contentTypes: contentTypes, installed: installed))
    }

    /// The apps opened so far, in order.
    public var opened: [URL] { state.withLock { $0.opened } }

    /// The next opening or change of default fails with this error.
    public func failNext(with error: any Error & Sendable) { state.withLock { $0.failure = error } }

    /// The user changes the default elsewhere.
    public func setDefault(_ application: InstalledApplication?, forScheme scheme: String) {
        state.withLock { $0.defaults[scheme.lowercased()] = application }
    }

    /// Installs or removes an app.
    public func setInstalled(_ url: URL?, bundleIdentifier: String) {
        state.withLock { $0.installed[bundleIdentifier] = url }
    }

    public func defaultApplication(forScheme scheme: String) async -> InstalledApplication? {
        state.withLock { $0.defaults[scheme.lowercased()] }
    }

    public func defaultApplication(forContentType type: UTType) async -> InstalledApplication? {
        state.withLock { $0.contentTypes[type.identifier] }
    }

    public func applicationURL(bundleIdentifier: String) async -> URL? {
        state.withLock { $0.installed[bundleIdentifier] }
    }

    public func openApplication(at url: URL) async throws {
        try state.withLock { state in
            try state.takeFailure()
            state.opened.append(url)
        }
    }

    public func makeDefault(_ url: URL, forScheme scheme: String) async throws {
        try state.withLock { state in
            try state.takeFailure()
            let name = url.deletingPathExtension().lastPathComponent
            let bundleIdentifier = state.installed.first { $0.value == url }?.key
            state.defaults[scheme.lowercased()] = InstalledApplication(
                url: url, bundleIdentifier: bundleIdentifier, name: name)
        }
    }
}

extension SimulatedDefaultApplications.State {
    fileprivate mutating func takeFailure() throws {
        guard let failure else { return }
        self.failure = nil
        throw failure
    }
}
