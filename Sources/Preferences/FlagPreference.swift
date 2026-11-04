import Foundation

/// A switch stored as text under the app's key, off by default: `1` or `0` when the app writes it, and a boolean written
/// with `defaults write … -bool YES` reads the same. A Debug build can force it on with an environment variable the app
/// names; the switch then shows on and cannot be turned off.
public struct FlagPreference: Sendable {
    public let key: String
    /// Forced on by the Debug environment.
    public let isForced: Bool

    private let store: any KeyValueStore

    public init(
        key: String, store: any KeyValueStore, forcingVariable: String, environment: [String: String], isDebugBuild: Bool
    ) {
        self.key = key
        self.store = store
        isForced = isDebugBuild && environment[forcingVariable] == "1"
    }

    public var isEnabled: Bool {
        isForced || ["1", "true", "yes"].contains(store.string(forKey: key)?.lowercased() ?? "")
    }

    public func set(_ enabled: Bool) {
        store.setString(enabled ? "1" : "0", forKey: key)
    }
}
