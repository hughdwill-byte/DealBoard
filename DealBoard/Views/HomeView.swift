import SwiftUI
import SwiftData

/// Home screen: pick a weekday (defaults to today) and see every deal that runs
/// that day, filterable by type. Fully offline.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Deal.title) private var allDeals: [Deal]

    @State private var selectedDay: Int = Weekday.today.rawValue
    @State private var typeFilter: DealType?
    @State private var showingAdd = false

    private var deals: [Deal] {
        allDeals
            .filter { deal in
                deal.weekdays.contains(selectedDay) &&
                (typeFilter == nil || deal.dealType == typeFilter)
            }
            // Earlier-in-the-day deals first; all-day deals (no start) sort last.
            .sorted { ($0.startMinutes ?? .max, $0.title) < ($1.startMinutes ?? .max, $1.title) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                WeekdayChips(selection: Binding(
                    get: { [selectedDay] },
                    set: { if let day = $0.first { selectedDay = day } }
                ), singleSelect: true)
                .padding(.top, 4)

                typeFilterBar

                if deals.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    dealList
                }
            }
            .background(Theme.background)
            .navigationTitle(Weekday(rawValue: selectedDay)?.full ?? "Deals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add deal")
                }
            }
            .sheet(isPresented: $showingAdd) {
                DealEditorView(deal: nil)
            }
        }
        .tint(Theme.accent)
    }

    private var typeFilterBar: some View {
        HStack(spacing: 8) {
            filterChip(nil, label: "All", symbol: "square.grid.2x2")
            ForEach(DealType.allCases) { type in
                filterChip(type, label: type.label, symbol: type.symbol)
            }
        }
        .padding(.horizontal)
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

    private var dealList: some View {
        List {
            ForEach(deals) { deal in
                ZStack {
                    NavigationLink(value: deal) { EmptyView() }.opacity(0)
                    DealCardView(deal: deal)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions {
                    Button(role: .destructive) { delete(deal) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Deal.self) { DealDetailView(deal: $0) }
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

#Preview {
    HomeView()
        .modelContainer(PreviewData.container)
}
