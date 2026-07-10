import Foundation
import SwiftData

@Model
final class Deal {
    var id: UUID = UUID()
    var title: String = ""
    /// Short editable summary of the key points (one per line).
    var keyPoints: String = ""
    /// Full OCR output, editable. Empty for manually-added deals.
    var rawText: String = ""
    var dealTypeRaw: String = DealType.food.rawValue
    /// Weekday indices (1 = Sun ... 7 = Sat) the deal recurs on.
    var weekdays: [Int] = []
    var price: String?
    var notes: String?
    /// Description of the event when dealType is .other (trivia, poker, comedy…).
    var otherDescription: String?
    /// Time-of-day windows the deal runs, each with an optional price. Multiple
    /// slots means a repeated deal at the same place/day was combined (e.g.
    /// $6 4–6pm and $8 8–10pm). Empty = fall back to the legacy single window
    /// below (older deals saved before slots existed).
    var timeSlots: [TimeSlot] = []
    /// Legacy single time window / price, kept for backward compatibility and as
    /// the fallback when `timeSlots` is empty. Mirrors the first slot on save.
    var startMinutes: Int?
    var endMinutes: Int?
    /// Filename (not full path) of the photo in Documents. Nil for no-photo deals.
    var imageFilename: String?
    var establishment: Establishment?
    var dateAdded: Date = Date()
    /// Last local edit — the last-write-wins clock for cloud sharing.
    var updatedAt: Date = Date()
    /// Soft-delete tombstone (only used while sharing, so a delete propagates).
    var isDeleted: Bool = false

    init(
        title: String = "",
        keyPoints: String = "",
        rawText: String = "",
        dealType: DealType = .food,
        weekdays: [Int] = [],
        price: String? = nil,
        notes: String? = nil,
        otherDescription: String? = nil,
        startMinutes: Int? = nil,
        endMinutes: Int? = nil,
        imageFilename: String? = nil,
        establishment: Establishment? = nil
    ) {
        self.title = title
        self.keyPoints = keyPoints
        self.rawText = rawText
        self.dealTypeRaw = dealType.rawValue
        self.weekdays = weekdays
        self.price = price
        self.notes = notes
        self.otherDescription = otherDescription
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.imageFilename = imageFilename
        self.establishment = establishment
        self.dateAdded = Date()
        self.updatedAt = Date()
    }

    /// Mark as edited now (bumps the sync clock).
    func touch() { updatedAt = Date() }

    /// Typed accessor over the stored raw string.
    var dealType: DealType {
        get { DealType(rawValue: dealTypeRaw) ?? .food }
        set { dealTypeRaw = newValue.rawValue }
    }

    func runs(on weekday: Weekday) -> Bool {
        weekdays.contains(weekday.rawValue)
    }

    // MARK: Time slots (combining)

    /// The slots to display, sorted earliest-first within the 6am→6am night
    /// (so an after-midnight window follows the evening rather than leading the
    /// morning). Prefers `timeSlots`; older deals fall back to the legacy fields.
    var orderedSlots: [TimeSlot] {
        let base = timeSlots.isEmpty ? legacySlots : timeSlots
        return base.sorted { a, b in
            let sa = a.startMinutes.map(DayBoundary.order) ?? Int.max
            let sb = b.startMinutes.map(DayBoundary.order) ?? Int.max
            return sa != sb ? sa < sb : (a.price ?? "") < (b.price ?? "")
        }
    }

    /// Sort key for ordering deals within a day's list (earliest window first,
    /// late-night last, no-time deals last of all).
    var sortStart: Int {
        orderedSlots.first?.startMinutes.map(DayBoundary.order) ?? Int.max
    }

    /// Single-slot view of the legacy fields (empty if there's nothing to show).
    private var legacySlots: [TimeSlot] {
        if startMinutes == nil, endMinutes == nil, (price ?? "").isEmpty { return [] }
        return [TimeSlot(startMinutes: startMinutes, endMinutes: endMinutes, price: price)]
    }

    /// True when the slots carry more than one distinct price.
    var pricesVary: Bool {
        let priced = orderedSlots
            .map { ($0.price ?? "").trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Set(priced).count > 1
    }

    /// The one price to show when it's uniform across slots; nil when prices vary
    /// (in which case each price is shown beside its own time).
    var displayPrice: String? {
        guard !pricesVary else { return nil }
        return orderedSlots.compactMap { $0.price }.first { !$0.isEmpty }
    }

    /// Times joined for a uniform-price deal: "4:00 PM – 6:00 PM and 8:00 PM – 10:00 PM".
    var timesLine: String? {
        let times = orderedSlots.compactMap { Self.slotTime($0) }
        return times.isEmpty ? nil : times.joined(separator: " and ")
    }

    /// Times with per-slot prices when they vary:
    /// "$6 from 4:00 PM – 6:00 PM, then $8 from 8:00 PM – 10:00 PM".
    var pricedTimesLine: String? {
        guard pricesVary else { return nil }
        let parts = orderedSlots.compactMap { slot -> String? in
            let time = Self.slotTime(slot)
            let p = (slot.price ?? "").trimmingCharacters(in: .whitespaces)
            switch (p.isEmpty, time) {
            case (false, let t?): return "\(p) from \(t)"
            case (false, nil):    return p
            case (true, let t?):  return t
            case (true, nil):     return nil
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", then ")
    }

    /// One line per slot for the detail view: "$6 · 4:00 PM – 6:00 PM".
    var slotDescriptions: [String] {
        orderedSlots.map { slot in
            let time = Self.slotTime(slot)
            let p = (slot.price ?? "").trimmingCharacters(in: .whitespaces)
            switch (p.isEmpty, time) {
            case (false, let t?): return "\(p) · \(t)"
            case (false, nil):    return p
            case (true, let t?):  return t
            case (true, nil):     return "All day"
            }
        }
    }

    /// Time range of one slot, or nil when it's all-day.
    static func slotTime(_ slot: TimeSlot) -> String? {
        switch (slot.startMinutes, slot.endMinutes) {
        case let (s?, e?): return "\(format(s)) – \(format(e))"
        case let (s?, nil): return "From \(format(s))"
        case let (nil, e?): return "Until \(format(e))"
        case (nil, nil): return nil
        }
    }

    /// Format minutes-since-midnight as a locale-aware time ("4:30 PM" / "16:30").
    static func format(_ minutes: Int) -> String {
        var comps = DateComponents()
        comps.hour = minutes / 60
        comps.minute = minutes % 60
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
