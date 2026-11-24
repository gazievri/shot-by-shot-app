import SwiftUI

nonisolated enum Category: String, Codable, CaseIterable, Sendable, Identifiable {
    case buy, read, watch, listen, cook, go, attend, todo, tryOut, contact, keep, inspire
    case other, `private`

    var id: String { rawValue }

    /// Categories a person can pick when keeping or moving a screenshot.
    /// Private stays out until it can be locked behind Face ID.
    static let selectable: [Category] = allCases.filter { $0 != .private }

    var defaultTitle: String {
        switch self {
        case .buy: String(localized: "Buy")
        case .read: String(localized: "Read")
        case .watch: String(localized: "Watch")
        case .listen: String(localized: "Listen")
        case .cook: String(localized: "Cook")
        case .go: String(localized: "Go")
        case .attend: String(localized: "Attend")
        case .todo: String(localized: "Do")
        case .tryOut: String(localized: "Try")
        case .contact: String(localized: "Contact")
        case .keep: String(localized: "Keep")
        case .inspire: String(localized: "Inspire")
        case .other: String(localized: "Other")
        case .private: String(localized: "Private")
        }
    }

    var symbolName: String {
        switch self {
        case .buy: "cart"
        case .read: "book"
        case .watch: "play.rectangle"
        case .listen: "headphones"
        case .cook: "fork.knife"
        case .go: "map"
        case .attend: "calendar"
        case .todo: "checklist"
        case .tryOut: "hand.tap"
        case .contact: "person.crop.circle"
        case .keep: "archivebox"
        case .inspire: "lightbulb"
        case .other: "square.grid.2x2"
        case .private: "lock"
        }
    }
}

extension EnvironmentValues {
    /// Names the person gave to categories, keyed by the category's raw value.
    @Entry var categoryTitles: [String: String] = [:]
}

extension Category {
    func title(in titles: [String: String]) -> String {
        titles[rawValue] ?? defaultTitle
    }
}
