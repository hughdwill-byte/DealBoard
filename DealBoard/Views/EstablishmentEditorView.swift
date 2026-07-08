import SwiftUI
import SwiftData
import CoreLocation

/// Add or edit an establishment. Coordinates are optional — you can save the
/// current location (so future photo-GPS matching works) or leave it blank.
struct EstablishmentEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var location = LocationService()

    let establishment: Establishment?
    var prefillCoordinate: CLLocationCoordinate2D?
    var onSave: ((Establishment) -> Void)?

    @State private var name = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var loaded = false

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
                Section("Name") {
                    TextField("Establishment name", text: $name)
                }
                Section("Details") {
                    TextField("Address (optional)", text: $address)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                }
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
                }
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
            .tint(Theme.accent)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let establishment {
            name = establishment.name
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
        }
    }

    private func save() {
        let target = establishment ?? Establishment()
        if establishment == nil { context.insert(target) }
        target.name = name.trimmingCharacters(in: .whitespaces)
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
