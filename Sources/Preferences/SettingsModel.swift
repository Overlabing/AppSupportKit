import Foundation
import Observation

/// Settings as a settings window reads and changes them: each change is saved at once, with no Apply button, as in
/// System Settings.
@MainActor @Observable
public final class SettingsModel<Value: Codable & Sendable & Equatable> {
    public private(set) var settings: Value
    /// The error met while loading (unreadable settings, defaults restored), for the app to report once.
    public private(set) var loadError: PreferenceError?

    private let preference: Preference<Value>

    public init(preference: Preference<Value>) {
        self.preference = preference
        do {
            settings = try preference.load()
        } catch {
            settings = preference.defaultValue
            loadError = error
        }
    }

    /// Changes then saves; when saving fails, the previous value is kept and the error is thrown.
    public func update(_ change: (inout Value) -> Void) throws {
        var updated = settings
        change(&updated)
        guard updated != settings else { return }
        try preference.save(updated)
        settings = updated
    }

    /// Replaces with settings computed elsewhere.
    public func replace(with updated: Value) throws {
        try update { $0 = updated }
    }

    /// The loading error, once.
    public func takeLoadError() -> PreferenceError? {
        defer { loadError = nil }
        return loadError
    }
}
