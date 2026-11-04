import Foundation
import Localization

func localized(_ keyAndValue: String.LocalizationValue) -> String {
    Localization.localized(keyAndValue, bundle: .module, pinnedTo: pinnedLanguage)
}

let pinnedLanguage = PinnedLanguage.read(PinnedLanguage.kitVariable)
