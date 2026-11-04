import Foundation

/// A user-facing string from `bundle`'s String Catalog. It follows the user's languages, exactly as
/// `String(localized:bundle:)`, unless a language is pinned (tests only, see `PinnedLanguage`).
///
/// `Bundle.module` belongs to each target, so each module keeps a one-line wrapper that passes its own bundle and pin:
///
///     func localized(_ value: String.LocalizationValue) -> String {
///         Localization.localized(value, bundle: .module, pinnedTo: pinnedLanguage)
///     }
public func localized(_ keyAndValue: String.LocalizationValue, bundle: Bundle, pinnedTo language: Locale?) -> String {
    guard let language else { return String(localized: keyAndValue, bundle: bundle) }
    // `String(localized:bundle:locale:)` ignores its locale for the lookup, and the build has no `lproj` for the
    // development language to pin a sub-bundle to (the keys are its text): a resource's locale does both.
    return String(localized: LocalizedStringResource(keyAndValue, locale: language, bundle: .atURL(bundle.bundleURL)))
}

/// The language a test run pins, so that a suite asserting sentences does not depend on the host's languages.
/// Neither an app nor a command-line tool sets it.
public enum PinnedLanguage {
    /// The variable every Overlabing kit reads for its own strings. An app pins its own strings with its own variable,
    /// and sets this one too when its tests read the kit's strings.
    public static let kitVariable = "OVERLABING_TEST_LANGUAGE"

    /// The language named by `variable` (`fr`, `en`), nil when it is unset or empty.
    public static func read(
        _ variable: String, from environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Locale? {
        guard let identifier = environment[variable], !identifier.isEmpty else { return nil }
        return Locale(identifier: identifier)
    }
}
