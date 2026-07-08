import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import PhotosUI

/// Add or edit an establishment. Coordinates are optional — set them by searching
/// the map, reading a photo's GPS metadata, capturing the current location, or
/// leave them blank. All manual fields still work with no connection.
struct EstablishmentEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var location = LocationService()
    @StateObject private var search = PlaceSearch()

    let establishment: Establishment?
    var prefillCoordinate: CLLocationCoordinate2D?
    var onSave: ((Establishment) -> Void)?

    @State private var name = ""
    @State private var specials = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var loaded = false

    // Map typeahead + photo-metadata location
    @State private var searchText = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoHadNoLocation = false

    // Nearby recommendations for a detected coordinate
    @State private var nearby: [EstablishmentCandidate] = []
    @State private var loadingNearby = false

    init(
        establishment: Establishment? = nil,
        prefillCoordinate: CLLocationCoordinate2D? = nil,
        onSave: ((Establishment) -> Void)? = nil
    ) {
        self.establishment = establishment
        self.prefillCoordinate = prefillCoordinate
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                searchSection
                Section("Name") {
                    TextField("Place name", text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section {
                    TextField("e.g. £5 pints, half-price mains", text: $specials, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Specials")
                } footer: {
                    Text("What this place's deals are known for. Shown on the home screen.")
                }
                Section("Details") {
                    TextField("Address (optional)", text: $address)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                }
                nearbySection
                Section("Location") {
                    if let latitude, let longitude {
                        Label(String(format: "%.5f, %.5f", latitude, longitude),
                              systemImage: "mappin.circle.fill")
                            .foregroundStyle(Theme.text)
                        Button("Clear location", role: .destructive) {
                            self.latitude = nil; self.longitude = nil
                        }
                    } else {
                        Text("No saved location.")
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Button {
                        Task { await useCurrentLocation() }
                    } label: {
                        HStack {
                            Label("Use current location", systemImage: "location")
                            if location.isRequesting {
                                Spacer(); ProgressView().controlSize(.mini)
                            }
                        }
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Get location from a photo", systemImage: "photo")
                    }
                    .buttonStyle(.borderless)
                    if photoHadNoLocation {
                        Text("That photo had no location data.")
                            .font(.footnote).foregroundStyle(Theme.secondaryText)
                    }
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await extractPhotoLocation(item) }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(establishment == nil ? "New Place" : "Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
            .task {
                // If we opened with a coordinate but no name yet (e.g. from the
                // deal photo flow), recommend the closest places right away.
                if establishment == nil, latitude != nil, name.isEmpty {
                    await loadNearby()
                }
            }
            .tint(Theme.accent)
        }
    }

    // MARK: Map typeahead

    private var searchSection: some View {
        Section {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondaryText)
                TextField("Search cafés, bars, restaurants…", text: $searchText)
                    .autocorrectionDisabled()
                    .onChange(of: searchText) { _, new in search.update(query: new) }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        search.suggestions = []
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.secondaryText)
                    }
                    .buttonStyle(.borderless)
                }
            }
            ForEach(search.suggestions, id: \.self) { suggestion in
                Button {
                    Task { await choosePlace(suggestion) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title).foregroundStyle(Theme.text)
                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle)
                                .font(.caption).foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
            }
        } header: {
            Text("Find on the map")
        } footer: {
            Text("Pick a result to fill in the name, address and location automatically. Works when you're online.")
        }
    }

    /// Resolve a chosen suggestion and fill the fields from it.
    private func choosePlace(_ completion: MKLocalSearchCompletion) async {
        guard let item = await search.resolve(completion) else { return }
        name = item.name ?? completion.title
        let placemark = item.placemark
        if let title = placemark.title, !title.isEmpty { address = title }
        latitude = placemark.coordinate.latitude
        longitude = placemark.coordinate.longitude
        searchText = ""
        search.suggestions = []
        Haptics.tap()
    }

    // MARK: Nearby recommendations

    /// Suggestions for a detected coordinate — closest food/drink places first.
    @ViewBuilder
    private var nearbySection: some View {
        if latitude != nil, loadingNearby || !nearby.isEmpty {
            Section {
                ForEach(nearby) { candidate in
                    Button {
                        pickNearby(candidate)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.name).foregroundStyle(Theme.text)
                                if let subtitle = candidate.subtitle {
                                    Text(subtitle).font(.caption).foregroundStyle(Theme.secondaryText)
                                }
                            }
                            Spacer()
                            Image(systemName: "mappin.circle").foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
                if loadingNearby && nearby.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.mini)
                        Text("Finding nearby places…").foregroundStyle(Theme.secondaryText)
                    }
                }
            } header: {
                Text("Nearby places")
            } footer: {
                Text("Closest first, from the detected location. Pick one to fill in the name and address.")
            }
        }
    }

    /// Fill the fields from a nearby suggestion.
    private func pickNearby(_ candidate: EstablishmentCandidate) {
        name = candidate.name
        if let a = candidate.address, !a.isEmpty { address = a }
        if let coord = candidate.coordinate {
            latitude = coord.latitude
            longitude = coord.longitude
        }
        Haptics.tap()
    }

    /// Look up nearby places for the current coordinate (online enrichment).
    private func loadNearby() async {
        guard let latitude, let longitude else { nearby = []; return }
        loadingNearby = true
        nearby = await EstablishmentMatcher.onlineNearby(
            to: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        loadingNearby = false
    }

    /// Read a coordinate out of a picked photo's metadata (EXIF, then PHAsset).
    private func extractPhotoLocation(_ item: PhotosPickerItem) async {
        photoHadNoLocation = false
        var coordinate: CLLocationCoordinate2D?
        if let data = try? await item.loadTransferable(type: Data.self) {
            coordinate = PhotoMetadata.coordinate(fromImageData: data)
        }
        if coordinate == nil {
            coordinate = await PhotoMetadata.coordinate(fromAssetIdentifier: item.itemIdentifier)
        }
        if let coordinate {
            latitude = coordinate.latitude
            longitude = coordinate.longitude
            Haptics.tap()
            await loadNearby()   // recommend the closest places for this location
        } else {
            photoHadNoLocation = true
            Haptics.warning()
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let establishment {
            name = establishment.name
            specials = establishment.specials ?? ""
            address = establishment.address ?? ""
            notes = establishment.notes ?? ""
            latitude = establishment.latitude
            longitude = establishment.longitude
        } else if let c = prefillCoordinate {
            latitude = c.latitude
            longitude = c.longitude
        }
    }

    private func useCurrentLocation() async {
        if let c = await location.currentCoordinate() {
            latitude = c.latitude
            longitude = c.longitude
            Haptics.tap()
            await loadNearby()   // recommend the closest places for this location
        }
    }

    private func save() {
        let target = establishment ?? Establishment()
        if establishment == nil { context.insert(target) }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.specials = specials.trimmingCharacters(in: .whitespaces).isEmpty ? nil : specials
        target.address = address.isEmpty ? nil : address
        target.notes = notes.isEmpty ? nil : notes
        target.latitude = latitude
        target.longitude = longitude
        Haptics.success()
        onSave?(target)
        dismiss()
    }
}

#Preview {
    EstablishmentEditorView()
        .modelContainer(PreviewData.container)
}
