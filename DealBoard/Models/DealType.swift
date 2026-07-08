import SwiftUI

/// The kind of deal an establishment is running.
/// Raw values are stored by SwiftData, so don't rename them casually.
enum DealType: String, Codable, CaseIterable, Identifiable {
    case food
    case drink
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .food: return "Food"
        case .drink: return "Drink"
        case .both: return "Food & Drink"
        }
    }

    var symbol: String {
        switch self {
        case .food: return "fork.knife"
        case .drink: return "wineglass"
        case .both: return "fork.knife.circle"
        }
    }

    /// Each type gets a distinct-but-harmonious accent from the warm palette.
    var accent: Color {
        switch self {
        case .food: return Theme.food
        case .drink: return Theme.drink
        case .both: return Theme.both
        }
    }
}
