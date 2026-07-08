import SwiftUI
import SwiftData

/// Home screen: pick a weekday (defaults to today) and see every deal that runs
/// that day, grouped by venue, filterable by type. Fully offline.
///
/// The whole screen — big title, day picker, type filters and the venue list —
/// lives inside one ScrollView so everything scrolls together as a unit.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Deal.title) private var allDeals: [Deal]

    @State private var selectedDay: Int = Weekday.today.rawValue
    @State private var typeFilter: DealType?
    @State private var showingAdd = false

    /// Deals on the selected day matching the current type filter (individual level).
    private var dayDeals: [Deal] {
        allDeals.filter { deal in
            deal.weekdays.contains(selectedDay) &&
            (typeFilter == nil || deal.dealType == typeFilter)
        }
    }

    /// The matching deals grouped by venue, venues sorted by name.
    private var venues: [VenueGroup] {
        let withVenue = dayDeals.filter { $0.establishment != nil }
        return Dictionary(grouping: withVenue, by: { $0.establishment!.id })
            .compactMap { _, deals -> VenueGroup? in
                guard let place = deals.first?.establishment else { return nil }
                return VenueGroup(id: place.id, name: place.name, specials: place.specials,
                                  deals: deals.sortedByTime())
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Deals with no venue assigned, shown in their own group.
    private var looseDeals: [Deal] {
        dayDeals.filter { $0.establishment == nil }.sortedByTime()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(Weekday(rawValue: selectedDay)?.full ?? "Deals")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal)

                    WeekdayChips(selection: Binding(
                        get: { [selectedDay] },
                        set: { if let day = $0.first { selectedDay = day } }
                    ), singleSelect: true)

                    typeFilterBar

                    if dayDeals.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity)
                            .padding(.top, 48)
                    } else {
                        ForEach(venues) { venue in
                            venueSection(name: venue.name, specials: venue.specials, deals: venue.deals)
                        }
                        if !looseDeals.isEmpty {
                            venueSection(name: "No place set", specials: nil, deals: looseDeals)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add deal")
                }
            }
            .navigationDestination(for: Deal.self) { DealDetailView(deal: $0) }
            .sheet(isPresented: $showingAdd) { DealEditorView(deal: nil) }
        }
        .tint(Theme.accent)
    }

    // MARK: Venue section

    private func venueSection(name: String, specials: String?, deals: [Deal]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Label(name, systemImage: "mappin.and.ellipse")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                if let specials, !specials.isEmpty {
                    Text(specials)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.horizontal)

            ForEach(deals) { deal in
                NavigationLink(value: deal) {
                    DealRowView(deal: deal)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .contextMenu {
                    Button(role: .destructive) { delete(deal) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: Type filter

    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, label: "All", symbol: "square.grid.2x2")
                ForEach(DealType.allCases) { type in
                    filterChip(type, label: type.label, symbol: type.symbol)
                }
            }
            .padding(.horizontal)
        }
    }

    private func filterChip(_ type: DealType?, label: String, symbol: String) -> some View {
        let isOn = typeFilter == type
        return Button {
            typeFilter = type
        } label: {
            Label(label, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isOn ? Theme.accent : Theme.secondaryBackground, in: Capsule())
                .foregroundStyle(isOn ? Color.white : Theme.text)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        EmptyStateView(
            symbol: "calendar.badge.exclamationmark",
            title: "No deals on \(Weekday(rawValue: selectedDay)?.full ?? "this day")",
            message: allDeals.isEmpty
                ? "Tap + to add your first deal from a photo or by hand."
                : "Try another day or clear the type filter."
        )
    }

    private func delete(_ deal: Deal) {
        ImageStore.delete(deal.imageFilename)
        context.delete(deal)
        Haptics.success()
    }
}

/// One venue's deals for the selected day.
private struct VenueGroup: Identifiable {
    let id: UUID
    let name: String
    let specials: String?
    let deals: [Deal]
}

private extension Array where Element == Deal {
    /// Earlier-in-the-day first; all-day deals (no start) sort last.
    func sortedByTime() -> [Deal] {
        sorted { ($0.startMinutes ?? .max, $0.title) < ($1.startMinutes ?? .max, $1.title) }
    }
}

#Preview {
    HomeView()
        .modelContainer(PreviewData.container)
}
