import Foundation

/// A Space edit refused by a rule, before anything is written.
public enum SpaceRuleError: Error, Sendable, Hashable {
    /// The name is empty once spaces are trimmed.
    case emptyName
    /// Another Space already has this name, case ignored.
    case duplicateName(String)
    /// A move outside the bounds of the list.
    case invalidMove
}

extension SpaceRuleError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyName: localized("Give the space a name.")
        case .duplicateName(let name): localized("A space named “\(name)” already exists.")
        case .invalidMove: localized("This space can't be moved there.")
        }
    }
}

/// The rules of an app's list of Spaces, pure and generic over its identifier. The app keeps the storage.
public enum SpaceRules {
    /// The name kept (spaces trimmed at both ends), when it is not empty and no Space among `existing` other than
    /// `excluding` has it, case ignored.
    public static func validateName<ID: Hashable>(
        _ name: String, among existing: [(id: ID, name: String)], excluding: ID? = nil
    ) throws(SpaceRuleError) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .emptyName }
        let taken = existing.contains { $0.id != excluding && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
        guard !taken else { throw .duplicateName(trimmed) }
        return trimmed
    }

    /// `ids` reordered as `List.onMove` does: the elements at `offsets` go before the element at `destination`
    /// (`ids.count`: at the end), in their relative order. An index out of bounds is an `invalidMove`.
    public static func moved<ID>(
        _ ids: [ID], fromOffsets offsets: IndexSet, toOffset destination: Int
    ) throws(SpaceRuleError) -> [ID] {
        guard !offsets.isEmpty, offsets.allSatisfy(ids.indices.contains), (0...ids.count).contains(destination) else {
            throw .invalidMove
        }
        let moving = offsets.map { ids[$0] }
        var rest = ids.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
        let insertion = destination - offsets.count(where: { $0 < destination })
        rest.insert(contentsOf: moving, at: insertion)
        return rest
    }

    /// The Space `step` away (±1) from `current`, wrapping at both ends; the first when there is no other or no current
    /// one, nil when there is none.
    public static func neighbor<ID: Equatable>(of current: ID?, in ids: [ID], step: Int) -> ID? {
        guard ids.count > 1, let current, let index = ids.firstIndex(of: current) else { return ids.first }
        let count = ids.count
        return ids[((index + step) % count + count) % count]
    }

    /// The Spaces that can take in what `deleted` holds: the default Space first (the proposed choice), then the others
    /// in order. When `deleted` is the default Space, the order alone counts.
    public static func deletionDestinations<ID: Equatable>(deleting deleted: ID, in ids: [ID], defaultSpace: ID?) -> [ID] {
        let others = ids.filter { $0 != deleted }
        guard let defaultSpace, defaultSpace != deleted, others.contains(defaultSpace) else { return others }
        return [defaultSpace] + others.filter { $0 != defaultSpace }
    }
}

/// The buttons of the "Delete Space…" confirmation: three at most, Cancel included (HIG: Alerts). Up to two
/// destinations, one button each; beyond, the proposed destination (the default Space, first in
/// `SpaceRules.deletionDestinations`) and "Choose…", which opens the whole list.
public enum SpaceDeletionChoices<ID: Hashable & Sendable>: Sendable, Hashable {
    /// An empty Space: one destructive button.
    case deleteEmpty
    /// One button per destination, the first the default.
    case moveTo([ID])
    /// The proposed destination, plus "Choose…" among all.
    case proposedOrChoose(proposed: ID, all: [ID])

    /// Beyond this many destinations, "Choose…" replaces the buttons.
    public static var maxDirectDestinations: Int { 2 }

    /// - Parameter contentCount: what the Space holds that must move (accounts, profiles); 0 for an empty Space.
    public init(contentCount: Int, destinations: [ID]) {
        if contentCount == 0 {
            self = .deleteEmpty
        } else if destinations.count > Self.maxDirectDestinations, let proposed = destinations.first {
            self = .proposedOrChoose(proposed: proposed, all: destinations)
        } else {
            self = .moveTo(destinations)
        }
    }

    /// The confirmation's buttons, Cancel included.
    public var buttonCount: Int {
        switch self {
        case .deleteEmpty: 2
        case .moveTo(let destinations): destinations.count + 1
        case .proposedOrChoose: 3
        }
    }
}
