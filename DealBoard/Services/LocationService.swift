import CoreLocation

/// Thin wrapper to grab the device's current location once, used only for the
/// optional "save current location" button when editing an establishment.
/// Everything else in the app works without any location permission.
@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isRequesting = false

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    /// Requests when-in-use permission if needed, then returns a single fix.
    /// Returns nil if permission is denied or a fix can't be obtained.
    func currentCoordinate() async -> CLLocationCoordinate2D? {
        isRequesting = true
        defer { isRequesting = false }

        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        guard manager.authorizationStatus != .denied,
              manager.authorizationStatus != .restricted else { return nil }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            continuation?.resume(returning: locations.last?.coordinate)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(returning: nil)
            continuation = nil
        }
    }
}
