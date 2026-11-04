/// What a Space shows as its icon: the initial of its name, an SF Symbol or an emoji, offered in one picker. Stored as
/// text: `initial`, `sf:<symbol>`, `emoji:<emoji>`. A bare symbol name (stored before this encoding) reads as a symbol,
/// an empty value or an empty symbol or emoji as the initial.
public enum SpaceGlyph: Sendable, Hashable {
    case initial
    case symbol(String)
    case emoji(String)

    static let symbolPrefix = "sf:"
    static let emojiPrefix = "emoji:"
    static let initialValue = "initial"

    public init(encoded: String) {
        if encoded.hasPrefix(Self.symbolPrefix) {
            let name = String(encoded.dropFirst(Self.symbolPrefix.count))
            self = name.isEmpty ? .initial : .symbol(name)
        } else if encoded.hasPrefix(Self.emojiPrefix) {
            let emoji = String(encoded.dropFirst(Self.emojiPrefix.count))
            self = emoji.isEmpty ? .initial : .emoji(emoji)
        } else if encoded.isEmpty || encoded == Self.initialValue {
            self = .initial
        } else {
            self = .symbol(encoded)
        }
    }

    public var encoded: String {
        switch self {
        case .initial: Self.initialValue
        case .symbol(let name): Self.symbolPrefix + name
        case .emoji(let emoji): Self.emojiPrefix + emoji
        }
    }

    /// The SF Symbol's name, nil for the initial and an emoji.
    public var symbolName: String? {
        if case .symbol(let name) = self { return name }
        return nil
    }

    /// The emoji, nil for the initial and a symbol.
    public var emoji: String? {
        if case .emoji(let emoji) = self { return emoji }
        return nil
    }
}
