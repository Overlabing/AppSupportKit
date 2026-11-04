/// What the user can do with a default where it is shown.
public enum DefaultControl: Hashable, Sendable {
    /// A switch, with the position it starts in.
    case toggle(isOn: Bool)
    /// A choice the user must make: nothing is preselected.
    case choice
    /// Something the app offers to do, such as becoming the default browser.
    case action
    /// A fact the user is told: a reminder, or a behaviour that has no switch in this version.
    case information
}

/// One entry of an app's registry of defaults: a choice the app makes for the user until they change it. Each default
/// is declared once, and onboarding and the settings that show defaults read the same entry. Texts are the app's,
/// already localized.
public struct DefaultEntry: Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    /// The default value as the user reads it, for example "On" or "Blocked".
    public let value: String
    public let explanation: String
    public let whereToChange: String
    public let control: DefaultControl
    /// Whether the default has a consequence the user should be told about. Onboarding and the settings show every
    /// user-facing entry and no other.
    public let isUserFacing: Bool
    /// An SF Symbol for the entry's card, nil for none.
    public let symbol: String?
    /// What leaves the device when the default is on, and to whom ("one request per sender's domain, to that site"):
    /// a privacy card says it under the switch. Nil when nothing does.
    public let disclosure: String?

    public init(
        id: String, title: String, value: String, explanation: String, whereToChange: String,
        control: DefaultControl = .information, isUserFacing: Bool = true, symbol: String? = nil,
        disclosure: String? = nil
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.explanation = explanation
        self.whereToChange = whereToChange
        self.control = control
        self.isUserFacing = isUserFacing
        self.symbol = symbol
        self.disclosure = disclosure
    }
}

extension Collection where Element == DefaultEntry {
    /// The entries onboarding and the settings show, in the registry's order.
    public var userFacing: [DefaultEntry] { filter(\.isUserFacing) }

    /// The entry with this identifier.
    public func entry(_ id: String) -> DefaultEntry? { first { $0.id == id } }
}
