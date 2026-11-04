/// An SF Symbol offered for a Space, with the name the menu shows and VoiceOver reads.
public struct SpaceIconChoice: Sendable, Hashable, Identifiable {
    public let symbol: String
    public let name: String

    public init(symbol: String, name: String) {
        self.symbol = symbol
        self.name = name
    }

    public var id: String { symbol }
}

/// The one catalogue of Space symbols: one list, one name per symbol.
public enum SpaceIconCatalog {
    /// The symbols offered, in the menu's order.
    public static var choices: [SpaceIconChoice] {
        [
            SpaceIconChoice(symbol: "house", name: localized("Home")),
            SpaceIconChoice(symbol: "briefcase", name: localized("Work")),
            SpaceIconChoice(symbol: "building.2", name: localized("Office")),
            SpaceIconChoice(symbol: "person", name: localized("Person")),
            SpaceIconChoice(symbol: "person.2", name: localized("Family")),
            SpaceIconChoice(symbol: "heart", name: localized("Heart")),
            SpaceIconChoice(symbol: "star", name: localized("Favorites")),
            SpaceIconChoice(symbol: "sparkles", name: localized("Sparkles")),
            SpaceIconChoice(symbol: "graduationcap", name: localized("Studies")),
            SpaceIconChoice(symbol: "book", name: localized("Reading")),
            SpaceIconChoice(symbol: "cart", name: localized("Shopping")),
            SpaceIconChoice(symbol: "airplane", name: localized("Travel")),
            SpaceIconChoice(symbol: "gamecontroller", name: localized("Games")),
            SpaceIconChoice(symbol: "leaf", name: localized("Nature")),
            SpaceIconChoice(symbol: "hammer", name: localized("DIY")),
        ]
    }

    /// The symbols offered, plus the Space's own when it is not one of them (chosen elsewhere or older), named by its
    /// symbol.
    public static func choices(including glyph: SpaceGlyph) -> [SpaceIconChoice] {
        let list = choices
        guard let current = glyph.symbolName, !list.contains(where: { $0.symbol == current }) else { return list }
        return list + [SpaceIconChoice(symbol: current, name: current)]
    }
}
