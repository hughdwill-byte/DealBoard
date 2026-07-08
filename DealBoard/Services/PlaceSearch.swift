import MapKit

/// Typeahead place search via MapKit's `MKLocalSearchCompleter`. As the user
/// types, it streams matching business/address suggestions; picking one resolves
/// to a full result with name, address and coordinate. This is optional online
/// enrichment — offline it simply returns no suggestions and the user types the
/// establishment in by hand, so nothing core breaks.
@MainActor
final class PlaceSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            suggestions = []
            return
        }
        completer.queryFragment = trimmed
    }

    /// Resolve a suggestion to name + address + coordinate. Returns nil offline.
    func resolve(_ completion: MKLocalSearchCompletion) async -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        return try? await MKLocalSearch(request: request).start().mapItems.first
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in self.suggestions = results }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.suggestions = [] }
    }
}
