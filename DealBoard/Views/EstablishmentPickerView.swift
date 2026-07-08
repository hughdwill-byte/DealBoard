import SwiftUI
import SwiftData
import CoreLocation

/// Lets the user confirm which establishment a deal belongs to. If the photo had
/// a coordinate we surface a ranked candidate list: offline (nearby saved places)
/// shown instantly, online (MapKit food/drink POIs) folded in when they arrive.
/// Always offers "None" and "Add new". Everything works without a coordinate.
struct EstablishmentPickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Establishment.name) private var establishments: [Establishment]

    let coordinate: CLLocationCoordinate2D?
    @Binding var selection: Establishment?

    @State private var candidates: [EstablishmentCandidate] = []
    @State private var isSearchingOnline = false
    @State private var showingNewEstablishment = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingNewEstablishment = true
                    } label: {
                        Label("Add new establishment", systemImage: "plus.circle")
                            .fontWeight(.semibold)
                    }
                    Button {
                        selection = nil
                        dismiss()
                    } label: {
                        Label("None", systemImage: "nosign")
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                if coordinate != nil {
                    candidatesSection
                }
                allSection
            }
            .navigationTitle("Establishment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingNewEstablishment) {
                // On save, pre-fill the coordinate so future matches work.
                EstablishmentEditorView(prefillCoordinate: coordinate) { created in
                    selection = created
                    dismiss()
                }
            }
            .task(id: coordinateKey) { await loadCandidates() }
        }
    }

    private var candidatesSection: some View {
        Section {
            if candidates.isEmpty && !isSearchingOnline {
                Text("No nearby matches. Pick from the list or add a new one.")
                    .font(.footnote).foregroundStyle(Theme.secondaryText)
            }
            ForEach(candidates) { candidate in
                Button {
                    choose(candidate)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.name).foregroundStyle(Theme.text)
                            if let subtitle = candidate.subtitle {
                                Text(subtitle).font(.caption).foregroundStyle(Theme.secondaryText)
                            }
                        }
                        Spacer()
                        Image(systemName: candidate.source == .saved ? "bookmark.fill" : "mappin.circle")
                            .foregroundStyle(candidate.source == .saved ? Theme.accent : Theme.secondaryText)
                    }
                }
            }
        } header: {
            HStack {
                Text("Suggested nearby")
                if isSearchingOnline {
                    ProgressView().controlSize(.mini)
                }
            }
        }
    }

    private var allSection: some View {
        Section("All establishments") {
            if establishments.isEmpty {
                Text("No establishments yet.")
                    .font(.footnote).foregroundStyle(Theme.secondaryText)
            }
            ForEach(establishments) { place in
                Button {
                    selection = place
                    dismiss()
                } label: {
                    HStack {
                        Text(place.name).foregroundStyle(Theme.text)
                        if place.id == selection?.id {
                            Spacer()
                            Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
        }
    }

    /// Stable key so `.task(id:)` reruns only when the coordinate actually changes.
    private var coordinateKey: String {
        guard let c = coordinate else { return "none" }
        return "\(c.latitude),\(c.longitude)"
    }

    private func loadCandidates() async {
        guard let coordinate else { candidates = []; return }

        // Offline first — instant.
        candidates = EstablishmentMatcher.nearbySaved(to: coordinate, in: establishments)

        // Online enrichment — non-blocking, merged in when it returns.
        isSearchingOnline = true
        let online = await EstablishmentMatcher.onlineNearby(to: coordinate)
        candidates = EstablishmentMatcher.merge(online: online, into: candidates)
        isSearchingOnline = false
    }

    private func choose(_ candidate: EstablishmentCandidate) {
        if let savedID = candidate.savedID,
           let match = establishments.first(where: { $0.id == savedID }) {
            selection = match
        } else {
            // Online candidate the user hasn't saved before — create it now so
            // it's reusable and future photo matching can find it.
            let place = Establishment(
                name: candidate.name,
                latitude: candidate.coordinate?.latitude,
                longitude: candidate.coordinate?.longitude
            )
            context.insert(place)
            selection = place
        }
        dismiss()
    }
}

#Preview {
    EstablishmentPickerView(coordinate: nil, selection: .constant(nil))
        .modelContainer(PreviewData.container)
}
