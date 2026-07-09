import Foundation

/// One time-of-day window a deal runs at, with an optional price for that window.
/// A deal can hold several — e.g. $6 beers 4–6pm, then $8 beers 8–10pm — which is
/// how the app combines repeated deals at the same place on the same day.
/// Stored on `Deal` as a Codable array (SwiftData persists it as an attribute).
struct TimeSlot: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var startMinutes: Int?   // minutes since midnight; nil = open-ended
    var endMinutes: Int?
    var price: String?

    /// Two slots are "the same window" if their time range and price match,
    /// regardless of id — used to de-duplicate when combining.
    func sameContent(as other: TimeSlot) -> Bool {
        startMinutes == other.startMinutes &&
        endMinutes == other.endMinutes &&
        (price ?? "") == (other.price ?? "")
    }
}
