import SwiftUI
import SwiftData

/// Establishments manager: list, add, edit, delete.
struct EstablishmentsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Establishment.name) private var establishments: [Establishment]

    @State private var editing: Establishment?
    @State private var showingNew = false
    @State private var addingDealFor: Establishment?

    var body: some View {
        NavigationStack {
            Group {
                if establishments.isEmpty {
                    EmptyStateView(
                        symbol: "storefront",
                        title: "No establishments yet",
                        message: "Add the places you visit. Save a location so photo deals can match them automatically."
                    )
                } else {
                    List {
                        ForEach(establishments) { place in
                            Button {
                                editing = place
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(place.name).font(.headline).foregroundStyle(Theme.text)
                                    if let address = place.address, !address.isEmpty {
                                        Text(address).font(.subheadline).foregroundStyle(Theme.secondaryText)
                                    }
                                    HStack(spacing: 12) {
                                        Label("\(place.deals?.count ?? 0) deals", systemImage: "tag")
                                        if place.hasLocation {
                                            Label("Located", systemImage: "mappin.circle.fill")
                                        }
                                    }
                                    .font(.caption).foregroundStyle(Theme.secondaryText)
                                }
                            }
                            .listRowBackground(Theme.card)
                            .swipeActions(edge: .leading) {
                                Button { addingDealFor = place } label: {
                                    Label("Add deal", systemImage: "plus")
                                }
                                .tint(Theme.accent)
                            }
                            .swipeActions {
                                Button(role: .destructive) { delete(place) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button { addingDealFor = place } label: {
                                    Label("Add deal here", systemImage: "plus")
                                }
                                Button { editing = place } label: {
                                    Label("Edit place", systemImage: "pencil")
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.background)
            .navigationTitle("Places")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add establishment")
                }
            }
            .sheet(item: $editing) { EstablishmentEditorView(establishment: $0) }
            .sheet(isPresented: $showingNew) { EstablishmentEditorView() }
            .sheet(item: $addingDealFor) { DealEditorView(deal: nil, prefillEstablishment: $0) }
        }
        .tint(Theme.accent)
    }

    private func delete(_ place: Establishment) {
        context.delete(place)
        Haptics.success()
    }
}

#Preview {
    EstablishmentsView()
        .modelContainer(PreviewData.container)
}
