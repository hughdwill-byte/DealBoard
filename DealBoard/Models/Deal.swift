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
    /// Optional time-of-day window the deal runs, stored as minutes since
    /// midnight (0–1439). Nil = runs all day. Two deals at the same place with
    /// different windows are simply two Deal rows.
    var startMinutes: Int?
    var endMinutes: Int?
    /// Filename (not full path) of the photo in Documents. Nil for no-photo deals.
    var imageFilename: String?
    var establishment: Establishment?
    var dateAdded: Date = Date()

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
    }

    /// Typed accessor over the stored raw string.
    var dealType: DealType {
        get { DealType(rawValue: dealTypeRaw) ?? .food }
        set { dealTypeRaw = newValue.rawValue }
    }

    func runs(on weekday: Weekday) -> Bool {
        weekdays.contains(weekday.rawValue)
    }

    /// Human summary of the time window, or nil when the deal runs all day.
    /// e.g. "4:00 PM – 6:00 PM", "From 9:00 PM", "Until 6:00 PM".
    var timeSummary: String? {
        switch (startMinutes, endMinutes) {
        case let (start?, end?): return "\(Self.format(start)) – \(Self.format(end))"
        case let (start?, nil):  return "From \(Self.format(start))"
        case let (nil, end?):    return "Until \(Self.format(end))"
        case (nil, nil):         return nil
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
