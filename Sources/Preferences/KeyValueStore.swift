import Foundation
import Synchronization

/// Where an app keeps its simple preferences: `UserDefaults` in the app, in memory in tests and demos.
public protocol KeyValueStore: Sendable {
    func string(forKey key: String) -> String?
    func setString(_ value: String?, forKey key: String)
    func data(forKey key: String) -> Data?
    func setData(_ value: Data?, forKey key: String)
}

extension UserDefaults: KeyValueStore {
    public func setString(_ value: String?, forKey key: String) { set(value, forKey: key) }
    public func setData(_ value: Data?, forKey key: String) { set(value, forKey: key) }
}

/// A store in memory, for tests and demos.
public final class InMemoryKeyValueStore: KeyValueStore {
    private let values = Mutex<[String: Any & Sendable]>([:])

    public init() {}

    public func string(forKey key: String) -> String? { values.withLock { $0[key] as? String } }
    public func setString(_ value: String?, forKey key: String) { values.withLock { $0[key] = value } }
    public func data(forKey key: String) -> Data? { values.withLock { $0[key] as? Data } }
    public func setData(_ value: Data?, forKey key: String) { values.withLock { $0[key] = value } }
}
