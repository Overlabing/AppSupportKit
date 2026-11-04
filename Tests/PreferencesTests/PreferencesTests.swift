import Foundation
import Preferences
import Testing

private struct Settings: Codable, Sendable, Equatable {
    var launchesHidden = false
    var name = "Default"

    init(launchesHidden: Bool = false, name: String = "Default") {
        self.launchesHidden = launchesHidden
        self.name = name
    }

    /// Tolerant: a field absent from an older value takes its default.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        launchesHidden = try container.decodeIfPresent(Bool.self, forKey: .launchesHidden) ?? false
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Default"
    }
}

@Suite struct PreferenceTests {
    private func preference(_ store: any KeyValueStore) -> Preference<Settings> {
        Preference(key: "app.settings", defaultValue: Settings(), store: store)
    }

    @Test func nothingStoredReadsTheDefault() throws {
        #expect(try preference(InMemoryKeyValueStore()).load() == Settings())
    }

    @Test func aSavedValueReadsBackWithSortedKeys() throws {
        let store = InMemoryKeyValueStore()
        try preference(store).save(Settings(launchesHidden: true, name: "Pro"))
        #expect(try preference(store).load() == Settings(launchesHidden: true, name: "Pro"))
        #expect(store.data(forKey: "app.settings") == Data(#"{"launchesHidden":true,"name":"Pro"}"#.utf8))
    }

    @Test func anOlderValueDecodesThroughTheValuesOwnTolerance() throws {
        let store = InMemoryKeyValueStore()
        store.setData(Data(#"{"launchesHidden":true}"#.utf8), forKey: "app.settings")
        #expect(try preference(store).load() == Settings(launchesHidden: true, name: "Default"))
    }

    @Test func anUnreadableValueThrows() {
        let store = InMemoryKeyValueStore()
        store.setData(Data("not json".utf8), forKey: "app.settings")
        #expect(throws: PreferenceError.unreadable(key: "app.settings")) { try preference(store).load() }
    }
}

@MainActor @Suite struct SettingsModelTests {
    @Test func aChangeIsSavedAtOnce() throws {
        let store = InMemoryKeyValueStore()
        let model = SettingsModel(preference: Preference(key: "app.settings", defaultValue: Settings(), store: store))
        try model.update { $0.name = "Pro" }
        #expect(model.settings.name == "Pro")
        let relaunched = SettingsModel(preference: Preference(key: "app.settings", defaultValue: Settings(), store: store))
        #expect(relaunched.settings.name == "Pro")
        try relaunched.replace(with: Settings(launchesHidden: true))
        #expect(relaunched.settings == Settings(launchesHidden: true))
    }

    @Test func anUpdateWithoutChangeWritesNothing() throws {
        let store = InMemoryKeyValueStore()
        let model = SettingsModel(preference: Preference(key: "app.settings", defaultValue: Settings(), store: store))
        try model.update { $0.name = "Default" }
        #expect(store.data(forKey: "app.settings") == nil)
    }

    @Test func unreadableSettingsRestoreTheDefaultsAndReportOnce() {
        let store = InMemoryKeyValueStore()
        store.setData(Data("{".utf8), forKey: "app.settings")
        let model = SettingsModel(preference: Preference(key: "app.settings", defaultValue: Settings(), store: store))
        #expect(model.settings == Settings())
        #expect(model.takeLoadError() == .unreadable(key: "app.settings"))
        #expect(model.takeLoadError() == nil)
    }

    /// `check.sh` pins French, then English (`OVERLABING_TEST_LANGUAGE`).
    @Test func theUnreadableMessageSpeaksThePinnedLanguage() {
        let message = PreferenceError.unreadable(key: "k").localizedDescription
        switch ProcessInfo.processInfo.environment["OVERLABING_TEST_LANGUAGE"] {
        case "fr": #expect(message == "Les réglages enregistrés sont illisibles ; les valeurs par défaut sont rétablies.")
        case "en": #expect(message == "The saved settings couldn't be read, so the defaults have been restored.")
        default: #expect(!message.isEmpty)
        }
    }
}

/// A switch that is opt-in, off by default, forced on only by the Debug environment.
@Suite struct FlagPreferenceTests {
    private func flag(_ store: any KeyValueStore, _ environment: [String: String] = [:], debug: Bool = true) -> FlagPreference {
        FlagPreference(
            key: "AppDiagnosticLog", store: store, forcingVariable: "APP_DEBUG_DIAGNOSTIC_LOG", environment: environment,
            isDebugBuild: debug)
    }

    @Test func offByDefaultThenWhatTheUserChose() {
        let store = InMemoryKeyValueStore()
        let preference = flag(store)
        #expect(!preference.isEnabled)
        preference.set(true)
        #expect(preference.isEnabled)
        #expect(store.string(forKey: "AppDiagnosticLog") == "1")
        preference.set(false)
        #expect(!preference.isEnabled)
    }

    @Test func readsABooleanWrittenByDefaults() {
        let store = InMemoryKeyValueStore()
        store.setString("YES", forKey: "AppDiagnosticLog")
        #expect(flag(store, debug: false).isEnabled)
    }

    @Test func debugEnvironmentForcesItOnInDebugOnly() {
        let environment = ["APP_DEBUG_DIAGNOSTIC_LOG": "1"]
        let debug = flag(InMemoryKeyValueStore(), environment, debug: true)
        #expect(debug.isForced && debug.isEnabled)
        debug.set(false)
        #expect(debug.isEnabled)
        let release = flag(InMemoryKeyValueStore(), environment, debug: false)
        #expect(!release.isForced && !release.isEnabled)
    }
}

@Suite struct DefaultEntryTests {
    private let entries = [
        DefaultEntry(
            id: "privacy.senderIcons", title: "Sender icons", value: "Off", explanation: "The sender's logo.",
            whereToChange: "Settings › Privacy", control: .toggle(isOn: false), symbol: "person.crop.square",
            disclosure: "One request per sender's domain."),
        DefaultEntry(
            id: "internal.cache", title: "Cache", value: "On", explanation: "e", whereToChange: "w", isUserFacing: false),
        DefaultEntry(id: "updates", title: "Updates", value: "Automatic", explanation: "e", whereToChange: "w"),
    ]

    @Test func onboardingAndSettingsReadTheUserFacingEntriesInOrder() {
        #expect(entries.userFacing.map(\.id) == ["privacy.senderIcons", "updates"])
        #expect(entries.entry("updates")?.title == "Updates")
        #expect(entries.entry("missing") == nil)
    }

    @Test func anEntryDefaultsToAUserFacingFactWithNothingDisclosed() {
        let entry = entries[2]
        #expect(entry.control == .information)
        #expect(entry.isUserFacing)
        #expect(entry.symbol == nil && entry.disclosure == nil)
        #expect(entries[0].control == .toggle(isOn: false))
        #expect(entries[0].disclosure == "One request per sender's domain.")
    }
}

@Suite struct KeyValueStoreTests {
    @Test func theInMemoryStoreKeepsStringsAndDataApart() {
        let store = InMemoryKeyValueStore()
        store.setString("a", forKey: "k")
        #expect(store.string(forKey: "k") == "a")
        #expect(store.data(forKey: "k") == nil)
        store.setData(Data([1]), forKey: "k")
        #expect(store.data(forKey: "k") == Data([1]))
        store.setString(nil, forKey: "k")
        #expect(store.string(forKey: "k") == nil && store.data(forKey: "k") == nil)
    }
}
