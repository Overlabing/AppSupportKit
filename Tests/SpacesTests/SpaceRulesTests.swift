import Foundation
import Spaces
import Testing

@Suite struct SpaceRulesTests {
    @Test func nameIsTrimmedAndUniqueIgnoringCase() throws {
        let pro = UUID()
        let existing = [(id: pro, name: "Pro"), (id: UUID(), name: "Perso")]
        #expect(try SpaceRules.validateName("  Hobby ", among: existing) == "Hobby")
        #expect(throws: SpaceRuleError.duplicateName("pro")) { try SpaceRules.validateName("pro", among: existing) }
        #expect(throws: SpaceRuleError.duplicateName("PERSO")) {
            try SpaceRules.validateName(" PERSO", among: existing, excluding: pro)
        }
        #expect(throws: SpaceRuleError.emptyName) { try SpaceRules.validateName(" \n ", among: existing) }
        // Renaming a Space to its own name with another case is allowed.
        #expect(try SpaceRules.validateName("PRO", among: existing, excluding: pro) == "PRO")
    }

    @Test func glyphEncodingRoundTrips() {
        #expect(SpaceGlyph.symbol("house").encoded == "sf:house")
        #expect(SpaceGlyph.initial.encoded == "initial")
        #expect(SpaceGlyph(encoded: "sf:house") == .symbol("house"))
        #expect(SpaceGlyph(encoded: "initial") == .initial)
        // Spaces stored before the encoding: a bare symbol name, or nothing.
        #expect(SpaceGlyph(encoded: "briefcase") == .symbol("briefcase"))
        #expect(SpaceGlyph(encoded: "") == .initial)
        #expect(SpaceGlyph(encoded: "sf:") == .initial)
        #expect(SpaceGlyph.symbol("leaf").symbolName == "leaf")
        #expect(SpaceGlyph.initial.symbolName == nil)
    }

    @Test func anEmojiIsTheThirdKindOfGlyph() {
        #expect(SpaceGlyph.emoji("🐦").encoded == "emoji:🐦")
        #expect(SpaceGlyph(encoded: "emoji:🐦") == .emoji("🐦"))
        #expect(SpaceGlyph(encoded: "emoji:👩‍👩‍👧") == .emoji("👩‍👩‍👧"))
        #expect(SpaceGlyph(encoded: "emoji:") == .initial)
        #expect(SpaceGlyph.emoji("🐦").emoji == "🐦")
        #expect(SpaceGlyph.emoji("🐦").symbolName == nil)
        #expect(SpaceGlyph.symbol("leaf").emoji == nil)
    }

    @Test func iconCatalogHasOneNamePerSymbol() {
        let choices = SpaceIconCatalog.choices
        #expect(!choices.isEmpty)
        #expect(Set(choices.map(\.symbol)).count == choices.count)
        #expect(Set(choices.map(\.name)).count == choices.count)
        #expect(choices.allSatisfy { !$0.name.isEmpty && $0.name != $0.symbol })
        // The symbol of a Space outside the catalogue goes at the end; a known symbol, the initial or an emoji change
        // nothing.
        #expect(SpaceIconCatalog.choices(including: .initial) == choices)
        #expect(SpaceIconCatalog.choices(including: .emoji("🐦")) == choices)
        #expect(SpaceIconCatalog.choices(including: .symbol("house")) == choices)
        #expect(SpaceIconCatalog.choices(including: .symbol("bolt")).last == SpaceIconChoice(symbol: "bolt", name: "bolt"))
    }

    /// `check.sh` pins French, then English (`OVERLABING_TEST_LANGUAGE`).
    @Test func theCatalogAndTheErrorsSpeakThePinnedLanguage() {
        let pinned = ProcessInfo.processInfo.environment["OVERLABING_TEST_LANGUAGE"]
        let names = SpaceIconCatalog.choices.map(\.name)
        let notFound = SpaceSwitchingError.spaceNotFound.localizedDescription
        let duplicate = SpaceRuleError.duplicateName("Pro").localizedDescription
        switch pinned {
        case "fr":
            #expect(names.first == "Maison" && names.contains("Achats") && names.last == "Bricolage")
            #expect(notFound == "Cet espace n'existe plus.")
            #expect(duplicate == "Un espace s'appelle déjà « Pro ».")
            #expect(SpaceRuleError.emptyName.localizedDescription == "Donnez un nom à l'espace.")
            #expect(SpaceRuleError.invalidMove.localizedDescription == "Cet espace ne peut pas être déplacé à cet endroit.")
        case "en":
            #expect(names.first == "Home" && names.contains("Shopping") && names.last == "DIY")
            #expect(notFound == "This space no longer exists.")
            #expect(duplicate == "A space named “Pro” already exists.")
        default:
            #expect(!notFound.isEmpty)
        }
    }

    @Test func deletionOffersAtMostThreeButtons() {
        let spaces = (0..<6).map { _ in UUID() }
        #expect(SpaceDeletionChoices(contentCount: 0, destinations: spaces) == .deleteEmpty)
        #expect(SpaceDeletionChoices(contentCount: 2, destinations: Array(spaces.prefix(1))) == .moveTo(Array(spaces.prefix(1))))
        #expect(SpaceDeletionChoices(contentCount: 2, destinations: Array(spaces.prefix(2))) == .moveTo(Array(spaces.prefix(2))))
        // Beyond two destinations: the proposed one (first, the default Space) and "Choose…" among all.
        #expect(
            SpaceDeletionChoices(contentCount: 1, destinations: Array(spaces.prefix(3)))
                == .proposedOrChoose(proposed: spaces[0], all: Array(spaces.prefix(3))))
        for count in 0...spaces.count {
            for content in [0, 1, 3] {
                let choices = SpaceDeletionChoices(contentCount: content, destinations: Array(spaces.prefix(count)))
                #expect(choices.buttonCount <= 3, "\(count) destinations, \(content) items")
            }
        }
    }

    @Test func destinationsPutTheDefaultSpaceFirst() {
        let (a, b, c) = (UUID(), UUID(), UUID())
        #expect(SpaceRules.deletionDestinations(deleting: a, in: [a, b, c], defaultSpace: c) == [c, b])
        #expect(SpaceRules.deletionDestinations(deleting: a, in: [a, b, c], defaultSpace: a) == [b, c])
        #expect(SpaceRules.deletionDestinations(deleting: b, in: [a, b, c], defaultSpace: nil) == [a, c])
        #expect(SpaceRules.deletionDestinations(deleting: a, in: [a], defaultSpace: a).isEmpty)
    }

    @Test func movedFollowsListOnMove() throws {
        let (a, b, c, d) = (UUID(), UUID(), UUID(), UUID())
        let ids = [a, b, c, d]
        #expect(try SpaceRules.moved(ids, fromOffsets: [0], toOffset: 4) == [b, c, d, a])
        #expect(try SpaceRules.moved(ids, fromOffsets: [3], toOffset: 0) == [d, a, b, c])
        #expect(try SpaceRules.moved(ids, fromOffsets: [0, 2], toOffset: 4) == [b, d, a, c])
        #expect(try SpaceRules.moved(ids, fromOffsets: [1], toOffset: 1) == ids)
        #expect(try SpaceRules.moved(ids, fromOffsets: [1], toOffset: 3) == [a, c, b, d])
    }

    @Test func invalidMovesAreRefused() {
        let ids = [UUID(), UUID()]
        #expect(throws: SpaceRuleError.invalidMove) { try SpaceRules.moved(ids, fromOffsets: [2], toOffset: 0) }
        #expect(throws: SpaceRuleError.invalidMove) { try SpaceRules.moved(ids, fromOffsets: [0], toOffset: 3) }
        #expect(throws: SpaceRuleError.invalidMove) { try SpaceRules.moved(ids, fromOffsets: [0], toOffset: -1) }
        #expect(throws: SpaceRuleError.invalidMove) { try SpaceRules.moved(ids, fromOffsets: [], toOffset: 0) }
    }

    @Test func neighborWrapsAround() {
        let (a, b, c) = (UUID(), UUID(), UUID())
        #expect(SpaceRules.neighbor(of: a, in: [a, b, c], step: 1) == b)
        #expect(SpaceRules.neighbor(of: c, in: [a, b, c], step: 1) == a)
        #expect(SpaceRules.neighbor(of: a, in: [a, b, c], step: -1) == c)
        #expect(SpaceRules.neighbor(of: a, in: [a], step: 1) == a)
        #expect(SpaceRules.neighbor(of: nil, in: [a, b], step: 1) == a)
        #expect(SpaceRules.neighbor(of: a, in: [UUID](), step: 1) == nil)
    }
}
