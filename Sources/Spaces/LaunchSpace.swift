import Preferences

/// Which Space opens at launch.
public enum LaunchSpaceBehavior: String, Sendable, Codable, CaseIterable, Identifiable {
    /// The default Space the user chose.
    case defaultSpace
    /// The last Space open, when it still exists.
    case lastSpace

    public var id: Self { self }
}

/// A Space identifier stored as text under the app's key. The app gives the key and how its identifier reads and
/// writes as text.
public struct StoredSpace<ID: Equatable & Sendable>: Sendable {
    public let key: String
    private let store: any KeyValueStore
    private let encode: @Sendable (ID) -> String
    private let decode: @Sendable (String) -> ID?

    public init(
        key: String, store: any KeyValueStore, encode: @escaping @Sendable (ID) -> String,
        decode: @escaping @Sendable (String) -> ID?
    ) {
        self.key = key
        self.store = store
        self.encode = encode
        self.decode = decode
    }

    /// The stored value, even when that Space no longer exists.
    public var stored: ID? { store.string(forKey: key).flatMap(decode) }

    /// Stores the Space; nil clears it.
    public func set(_ id: ID?) {
        store.setString(id.map(encode), forKey: key)
    }

    /// Stores the current Space as the last one; nil (no Space) keeps the previous value, and an unchanged value is not
    /// written again.
    public func remember(_ id: ID?) {
        guard let id, id != stored else { return }
        store.setString(encode(id), forKey: key)
    }
}

/// The Space to open at launch.
public enum LaunchSpace {
    /// The default Space: the stored one if it still exists, else the first; nil without a Space.
    public static func defaultSpace<ID: Equatable>(stored: ID?, in spaces: [ID]) -> ID? {
        if let stored, spaces.contains(stored) { return stored }
        return spaces.first
    }

    /// The Space `behavior` opens: the last Space when it still exists, else the default Space (already resolved by
    /// `defaultSpace(stored:in:)`).
    public static func resolve<ID: Equatable>(
        _ behavior: LaunchSpaceBehavior, defaultSpace: ID?, lastSpace: ID?, existing: [ID]
    ) -> ID? {
        if behavior == .lastSpace, let lastSpace, existing.contains(lastSpace) { return lastSpace }
        return defaultSpace
    }
}
