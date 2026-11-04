#if os(macOS)
import AppKit
import UniformTypeIdentifiers

/// LaunchServices through `NSWorkspace`. From the sandbox it reads and opens only: `setDefaultApplication` fails with
/// `permErr` (-54) for any URL or scheme (Apple DTS, https://developer.apple.com/forums/thread/731555).
public struct WorkspaceDefaultApplications: DefaultApplicationClient {
    public init() {}

    public func defaultApplication(forScheme scheme: String) async -> InstalledApplication? {
        guard let probe = URL(string: "\(scheme):"), let url = NSWorkspace.shared.urlForApplication(toOpen: probe) else {
            return nil
        }
        return Self.application(at: url)
    }

    public func defaultApplication(forContentType type: UTType) async -> InstalledApplication? {
        NSWorkspace.shared.urlForApplication(toOpen: type).map(Self.application(at:))
    }

    public func applicationURL(bundleIdentifier: String) async -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    /// `openApplication` rather than `open(_:)`, whose `Bool` would leave nothing to report on a failure.
    public func openApplication(at url: URL) async throws {
        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    public func makeDefault(_ url: URL, forScheme scheme: String) async throws {
        try await NSWorkspace.shared.setDefaultApplication(at: url, toOpenURLsWithScheme: scheme)
    }

    private static func application(at url: URL) -> InstalledApplication {
        InstalledApplication(
            url: url, bundleIdentifier: Bundle(url: url)?.bundleIdentifier,
            name: FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""))
    }
}
#endif
