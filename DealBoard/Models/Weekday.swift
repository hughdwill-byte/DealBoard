import Foundation

/// The app treats a day as running 6am → 6am. Times before 6am are "late night"
/// belonging to the previous evening, for both "what day is it" and sort order.
enum DayBoundary {
    static let startMinutes = 6 * 60   // 6:00 AM

    /// Remap minutes-since-midnight so a night sorts in real order: 6am is
    /// earliest, late-evening next, and after-midnight last (not first).
    static func order(_ minutes: Int) -> Int {
        minutes < startMinutes ? minutes + 24 * 60 : minutes
    }
}

/// Weekdays are stored as `Int` indices using Calendar's convention:
/// 1 = Sunday ... 7 = Saturday. This matches `Calendar.component(.weekday)`
/// so "today" is trivial to compute without any conversion.
enum Weekday: Int, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    /// The current "night". Days start at 6am, so before 6am still counts as the
    /// previous evening (a deal running past midnight belongs to that night).
    static var today: Weekday {
        let cal = Calendar.current
        let adjusted = cal.date(byAdding: .minute, value: -DayBoundary.startMinutes, to: Date()) ?? Date()
        return Weekday(rawValue: cal.component(.weekday, from: adjusted)) ?? .monday
    }

    /// Display order Monday → Sunday (the raw values keep Calendar's Sun=1 basis).
    static let mondayFirst: [Weekday] = [.monday, .tuesday, .wednesday, .thursday,
                                         .friday, .saturday, .sunday]

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
        let set = Set(self)
        let ordered = Weekday.mondayFirst.filter { set.contains($0.rawValue) }
        guard !ordered.isEmpty else { return "No days set" }
        if ordered.count == 7 { return "Every day" }
        return ordered.map(\.short).joined(separator: ", ")
    }
}
