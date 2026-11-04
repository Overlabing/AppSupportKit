import Foundation

/// A Space as a menu or a system intent offers it.
public struct SpaceChoice<ID: Hashable & Sendable>: Sendable, Hashable, Identifiable {
    public var id: ID
    public var name: String
    /// The Space shown in the main window (checked in a menu).
    public var isCurrent: Bool

    public init(id: ID, name: String, isCurrent: Bool) {
        self.id = id
        self.name = name
        self.isCurrent = isCurrent
    }
}

public enum SpaceSwitchingError: LocalizedError, Hashable {
    /// The Space was deleted since a menu or an intent listed it.
    case spaceNotFound

    public var errorDescription: String? {
        switch self {
        case .spaceNotFound: localized("This space no longer exists.")
        }
    }
}

/// Switching Space: from a menu, a system intent (Shortcuts, Spotlight) or a tab bar. Pure: the app gives its Spaces
/// in its own order.
public enum SpaceSwitching {
    /// One choice per Space, in order, the current one marked.
    public static func choices<ID>(_ spaces: [(id: ID, name: String)], current: ID?) -> [SpaceChoice<ID>] {
        spaces.map { SpaceChoice(id: $0.id, name: $0.name, isCurrent: $0.id == current) }
    }

    /// The Spaces whose name matches `text`, case and accents ignored: names that start with it first, then names that
    /// contain it, each in order. A blank text matches every Space.
    public static func matching<ID>(_ text: String, in spaces: [SpaceChoice<ID>]) -> [SpaceChoice<ID>] {
        let query = fold(text)
        guard !query.isEmpty else { return spaces }
        let prefixed = spaces.filter { fold($0.name).hasPrefix(query) }
        let containing = spaces.filter { !fold($0.name).hasPrefix(query) && fold($0.name).contains(query) }
        return prefixed + containing
    }

    /// The Space an intent or a menu item asks for, if it still exists.
    public static func target<ID>(_ id: ID, in spaces: [SpaceChoice<ID>]) throws -> ID {
        guard spaces.contains(where: { $0.id == id }) else { throw SpaceSwitchingError.spaceNotFound }
        return id
    }

    /// The Spaces a bar with room for `limit` shows: the first ones in order. The current Space, reached some other way
    /// when it is further down, takes the last place: the bar always shows where the user is.
    public static func visible<ID: Equatable>(_ spaces: [ID], current: ID?, limit: Int) -> [ID] {
        guard limit > 0 else { return [] }
        var shown = Array(spaces.prefix(limit))
        if let current, spaces.contains(current), !shown.contains(current) {
            shown[shown.count - 1] = current
        }
        return shown
    }

    /// The Space whose tab is selected: the current one, else the first. Never none while Spaces exist.
    public static func selected<ID: Equatable>(_ spaces: [ID], current: ID?) -> ID? {
        if let current, spaces.contains(current) { return current }
        return spaces.first
    }

    private static func fold(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
