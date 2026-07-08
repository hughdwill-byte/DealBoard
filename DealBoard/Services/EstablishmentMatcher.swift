import Foundation
import CoreLocation
import MapKit

/// A candidate establishment for the photo's location, from any source.
struct EstablishmentCandidate: Identifiable, Hashable {
    enum Source: Hashable {
        case saved            // already in the user's list (offline match)
        case online           // MapKit POI / reverse geocode
    }
    let id = UUID()
    var name: String
    var subtitle: String?     // distance or address
    var source: Source
    var coordinate: CLLocationCoordinate2D?
    /// Set when the candidate is one of the user's existing establishments.
    var savedID: UUID?

    static func == (l: EstablishmentCandidate, r: EstablishmentCandidate) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Ranks candidate establishments for a photo coordinate. Offline results come
/// first and immediately; online results are folded in when/if they arrive.
enum EstablishmentMatcher {
    /// Radius for considering a saved establishment "at" the photo location.
    static let nearbyRadius: CLLocationDistance = 250

    // MARK: Offline — distance to already-saved establishments

    /// Saved establishments within `nearbyRadius`, closest first. No network.
    static func nearbySaved(
        to coordinate: CLLocationCoordinate2D,
        in establishments: [Establishment]
    ) -> [EstablishmentCandidate] {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        return establishments
            .compactMap { place -> (Establishment, CLLocationDistance)? in
                guard let c = place.coordinate else { return nil }
                let distance = origin.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude))
                return distance <= nearbyRadius ? (place, distance) : nil
            }
            .sorted { $0.1 < $1.1 }
            .map { place, distance in
                EstablishmentCandidate(
                    name: place.name,
                    subtitle: "\(Int(distance)) m away",
                    source: .saved,
                    coordinate: place.coordinate,
                    savedID: place.id
                )
            }
    }

    // MARK: Online — MapKit POI search (optional enrichment)

    /// Nearby food & drink businesses from MapKit. This is the only networked
    /// call in the app; it's optional. On any failure (offline, timeout) it
    /// returns [] and the flow continues with offline/manual options.
    static func onlineNearby(to coordinate: CLLocationCoordinate2D) async -> [EstablishmentCandidate] {
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: nearbyRadius * 2,
            longitudinalMeters: nearbyRadius * 2
        )
        let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .restaurant, .cafe, .bakery, .brewery, .winery, .nightlife, .foodMarket
        ])

        do {
            let response = try await MKLocalSearch(request: request).start()
            let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            return response.mapItems.compactMap { item in
                guard let name = item.name else { return nil }
                let subtitle: String?
                if let loc = item.placemark.location {
                    subtitle = "\(Int(origin.distance(from: loc))) m away"
                } else {
                    subtitle = item.placemark.title
                }
                return EstablishmentCandidate(
                    name: name,
                    subtitle: subtitle,
                    source: .online,
                    coordinate: item.placemark.coordinate
                )
            }
        } catch {
            return []   // offline or no results — degrade gracefully
        }
    }

    /// Merge online candidates into an existing list, dropping names already
    /// present (case-insensitive) so a saved place isn't shown twice.
    static func merge(
        online: [EstablishmentCandidate],
        into existing: [EstablishmentCandidate]
    ) -> [EstablishmentCandidate] {
        let known = Set(existing.map { $0.name.lowercased() })
        return existing + online.filter { !known.contains($0.name.lowercased()) }
    }
}
