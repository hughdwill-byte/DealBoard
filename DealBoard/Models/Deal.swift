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
}
