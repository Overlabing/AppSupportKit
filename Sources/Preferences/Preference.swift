import Foundation

/// A value stored as JSON under one key of a `KeyValueStore`. The key belongs to the app: the kit never names one.
/// Decoding is as tolerant as `Value`'s own `init(from:)`: a value that adds a field later decodes an older one by
/// giving that field its default there.
public struct Preference<Value: Codable & Sendable>: Sendable {
    public let key: String
    public let defaultValue: Value
    private let store: any KeyValueStore

    public init(key: String, defaultValue: Value, store: any KeyValueStore) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = store
    }

    /// The stored value, the default when nothing is stored. An unreadable value throws: the caller reports it and
    /// starts again from the default.
    public func load() throws(PreferenceError) -> Value {
        guard let data = store.data(forKey: key) else { return defaultValue }
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            throw .unreadable(key: key)
        }
    }

    /// Stores the value, keys sorted so that the same value always writes the same bytes.
    public func save(_ value: Value) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        store.setData(try encoder.encode(value), forKey: key)
    }
}

public enum PreferenceError: Error, Sendable, Hashable {
    /// The stored value could not be decoded; the default replaces it.
    case unreadable(key: String)
}

extension PreferenceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unreadable: localized("The saved settings couldn't be read, so the defaults have been restored.")
        }
    }
}
