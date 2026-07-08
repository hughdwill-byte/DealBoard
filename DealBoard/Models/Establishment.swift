import Foundation
import SwiftData
import CoreLocation

@Model
final class Establishment {
    var id: UUID = UUID()
    var name: String = ""
    /// Short description of what this place's specials are (e.g. "£5 pints &
    /// half-price mains"). Shown on the home cards so you know at a glance what
    /// the place is known for.
    var specials: String?
    var address: String?
    /// Optional saved coordinate. When present, future photo-GPS matching can
    /// find this place. Stored as two optionals because SwiftData can't persist
    /// CLLocationCoordinate2D directly.
    var latitude: Double?
    var longitude: Double?
    var notes: String?

    @Relationship(deleteRule: .nullify, inverse: \Deal.establishment)
    var deals: [Deal]? = []

    init(
        name: String = "",
        specials: String? = nil,
        address: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        notes: String? = nil
    ) {
        self.name = name
        self.specials = specials
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.notes = notes
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var hasLocation: Bool { latitude != nil && longitude != nil }
}
