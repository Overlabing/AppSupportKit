import Foundation
import Spaces
import Testing

/// A menu, a system intent (Shortcuts, Spotlight) and a tab bar switch Space through the same rules.
@Suite struct SpaceSwitchingTests {
    let pro = UUID()
    let perso = UUID()
    let asso = UUID()

    var spaces: [(id: UUID, name: String)] { [(pro, "Pro"), (perso, "Perso"), (asso, "Événements Pro")] }

    @Test func aMenuListsEverySpaceInOrderWithTheCurrentOneChecked() {
        let choices = SpaceSwitching.choices(spaces, current: perso)
        #expect(choices.map(\.name) == ["Pro", "Perso", "Événements Pro"])
        #expect(choices.map(\.isCurrent) == [false, true, false])
        #expect(SpaceSwitching.choices(spaces, current: nil).allSatisfy { !$0.isCurrent })
        #expect(SpaceSwitching.choices([(id: UUID, name: String)](), current: pro).isEmpty)
    }

    @Test func aSpokenOrTypedNameFindsItsSpaceIgnoringCaseAndAccents() {
        let choices = SpaceSwitching.choices(spaces, current: pro)
        #expect(SpaceSwitching.matching("pro", in: choices).map(\.id) == [pro, asso])
        #expect(SpaceSwitching.matching("evenements", in: choices).map(\.id) == [asso])
        #expect(SpaceSwitching.matching("PERS", in: choices).map(\.id) == [perso])
        #expect(SpaceSwitching.matching("  ", in: choices).count == 3)
        #expect(SpaceSwitching.matching("Famille", in: choices).isEmpty)
    }

    @Test func anIntentSwitchesToAnExistingSpaceOnly() throws {
        let choices = SpaceSwitching.choices(spaces, current: pro)
        #expect(try SpaceSwitching.target(perso, in: choices) == perso)
        #expect(throws: SpaceSwitchingError.spaceNotFound) { try SpaceSwitching.target(UUID(), in: choices) }
    }
}

/// The Spaces a bar with limited room shows.
@Suite struct VisibleSpacesTests {
    private let spaces = (0..<6).map { _ in UUID() }

    @Test func fewSpacesAreAllShownInOrder() {
        let few = Array(spaces.prefix(3))
        #expect(SpaceSwitching.visible(few, current: few[1], limit: 4) == few)
    }

    @Test func theLimitKeepsTheFirstSpaces() {
        #expect(SpaceSwitching.visible(spaces, current: spaces[2], limit: 4) == Array(spaces.prefix(4)))
    }

    @Test func aCurrentSpaceFurtherDownTakesTheLastPlace() {
        #expect(SpaceSwitching.visible(spaces, current: spaces[5], limit: 4) == [spaces[0], spaces[1], spaces[2], spaces[5]])
    }

    @Test func theSelectedTabIsTheCurrentSpace() {
        #expect(SpaceSwitching.selected(spaces, current: spaces[2]) == spaces[2])
    }

    /// Two Spaces or more and no current one yet (the load): never no tab.
    @Test func withoutACurrentSpaceTheFirstTabIsSelected() {
        #expect(SpaceSwitching.selected(spaces, current: nil) == spaces[0])
        #expect(SpaceSwitching.selected(spaces, current: UUID()) == spaces[0])
        #expect(SpaceSwitching.selected([UUID](), current: nil) == nil)
    }

    @Test func anUnknownOrMissingCurrentChangesNothing() {
        #expect(SpaceSwitching.visible(spaces, current: nil, limit: 4) == Array(spaces.prefix(4)))
        #expect(SpaceSwitching.visible(spaces, current: UUID(), limit: 4) == Array(spaces.prefix(4)))
    }

    @Test func noRoomNoTabs() {
        #expect(SpaceSwitching.visible(spaces, current: spaces[0], limit: 0).isEmpty)
        #expect(SpaceSwitching.visible([UUID](), current: nil, limit: 4).isEmpty)
    }
}
