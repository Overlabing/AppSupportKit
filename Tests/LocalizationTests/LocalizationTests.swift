import Foundation
import Localization
import Testing

/// A suite that asserts sentences must not depend on the host's languages.
@Suite struct LocalizationTests {
    private func text(_ value: String.LocalizationValue, _ language: String?) -> String {
        localized(value, bundle: .module, pinnedTo: language.map(Locale.init(identifier:)))
    }

    /// Whatever the host prefers, a pinned language decides: English returns the key, French its translation. One of the
    /// two always contradicts the host's first language.
    @Test func aPinnedLanguageWinsOverTheHostLanguages() {
        #expect(text("Shopping", "fr") == "Achats")
        #expect(text("Shopping", "en") == "Shopping")
        // Interpolations keep working through the pinned path.
        #expect(text("To: \("Claire")", "fr") == "À : Claire")
    }

    @Test func thePinIsReadFromTheVariableTheCallerNames() {
        #expect(PinnedLanguage.read("APP_TEST_LANGUAGE", from: ["APP_TEST_LANGUAGE": "fr"]) == Locale(identifier: "fr"))
        #expect(PinnedLanguage.read("APP_TEST_LANGUAGE", from: ["OTHER": "fr"]) == nil)
        #expect(PinnedLanguage.read("APP_TEST_LANGUAGE", from: ["APP_TEST_LANGUAGE": ""]) == nil)
        #expect(PinnedLanguage.kitVariable == "OVERLABING_TEST_LANGUAGE")
    }
}
