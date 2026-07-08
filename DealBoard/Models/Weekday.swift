import Foundation

/// Weekdays are stored as `Int` indices using Calendar's convention:
/// 1 = Sunday ... 7 = Saturday. This matches `Calendar.component(.weekday)`
/// so "today" is trivial to compute without any conversion.
enum Weekday: Int, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    static var today: Weekday {
        Weekday(rawValue: Calendar.current.component(.weekday, from: Date())) ?? .monday
    }

    /// Short symbol ("Mon"), localised. `shortWeekdaySymbols` is 0-indexed with Sunday first.
    var short: String {
        Calendar.current.shortWeekdaySymbols[rawValue - 1]
    }

    /// Single-letter label for compact chips.
    var narrow: String {
        Calendar.current.veryShortWeekdaySymbols[rawValue - 1]
    }

    var full: String {
        Calendar.current.weekdaySymbols[rawValue - 1]
    }
}

extension Array where Element == Int {
    /// Compact human summary of the weekdays a deal runs, e.g. "Mon, Wed, Fri".
    var weekdaySummary: String {
        let ordered = compactMap { Weekday(rawValue: $0) }.sorted { $0.rawValue < $1.rawValue }
        guard !ordered.isEmpty else { return "No days set" }
        if ordered.count == 7 { return "Every day" }
        return ordered.map(\.short).joined(separator: ", ")
    }
}
