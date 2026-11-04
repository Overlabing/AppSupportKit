import Foundation
import Preferences
import Spaces
import Testing

@Suite struct LaunchSpaceTests {
    private func stored(_ store: any KeyValueStore, key: String = "app.defaultSpaceID") -> StoredSpace<UUID> {
        StoredSpace(key: key, store: store, encode: \.uuidString, decode: UUID.init(uuidString:))
    }

    @Test("The default Space: the stored one when it exists, else the first, nil without a Space")
    func defaultSpaceFallback() {
        let store = InMemoryKeyValueStore()
        let preference = stored(store)
        let first = UUID(), second = UUID()

        #expect(LaunchSpace.defaultSpace(stored: preference.stored, in: [first, second]) == first)
        preference.set(second)
        #expect(store.string(forKey: "app.defaultSpaceID") == second.uuidString)
        #expect(LaunchSpace.defaultSpace(stored: preference.stored, in: [first, second]) == second)
        // A deleted Space: back to the first, the stored value stays readable.
        #expect(LaunchSpace.defaultSpace(stored: preference.stored, in: [first]) == first)
        #expect(preference.stored == second)
        #expect(LaunchSpace.defaultSpace(stored: preference.stored, in: []) == nil)
        preference.set(nil)
        #expect(preference.stored == nil)
    }

    @Test("An unreadable stored Space is ignored")
    func garbageIsIgnored() {
        let store = InMemoryKeyValueStore()
        store.setString("not-a-uuid", forKey: "app.defaultSpaceID")
        let first = UUID()
        #expect(stored(store).stored == nil)
        #expect(LaunchSpace.defaultSpace(stored: stored(store).stored, in: [first]) == first)
    }

    @Test("The last Space: remembered at each change, nil keeps it, read again after a relaunch")
    func lastSpaceRemembered() {
        let store = InMemoryKeyValueStore()
        let first = UUID(), second = UUID()
        let tracker = stored(store, key: "app.lastSpaceID")
        tracker.remember(first)
        tracker.remember(second)
        tracker.remember(nil)
        #expect(stored(store, key: "app.lastSpaceID").stored == second)
        #expect(store.string(forKey: "app.defaultSpaceID") == nil)
    }

    @Test("The launch behaviour picks the last Space only when it still exists")
    func launchSpace() {
        let first = UUID(), second = UUID(), gone = UUID()
        #expect(LaunchSpace.resolve(.lastSpace, defaultSpace: first, lastSpace: second, existing: [first, second]) == second)
        #expect(LaunchSpace.resolve(.lastSpace, defaultSpace: first, lastSpace: gone, existing: [first, second]) == first)
        #expect(LaunchSpace.resolve(.lastSpace, defaultSpace: first, lastSpace: nil, existing: [first]) == first)
        #expect(LaunchSpace.resolve(.defaultSpace, defaultSpace: first, lastSpace: second, existing: [first, second]) == first)
        #expect(LaunchSpaceBehavior(rawValue: "lastSpace") == .lastSpace)
        #expect(LaunchSpaceBehavior.defaultSpace.rawValue == "defaultSpace")
    }
}
