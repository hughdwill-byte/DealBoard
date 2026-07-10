import SwiftUI
import SwiftData

@main
struct DealBoardApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // Local, on-device SwiftData store. No cloud, no sync, no accounts.
        .modelContainer(for: [Deal.self, Establishment.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Deals", systemImage: "calendar") }
            EstablishmentsView()
                .tabItem { Label("Places", systemImage: "mappin.and.ellipse") }
        }
        .tint(Theme.accent)
        .task {
            CloudSharing.shared.context = context
            backfillDuplicatesOnce()
            await CloudSharing.shared.syncNow()   // no-op unless sharing is set up
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await CloudSharing.shared.syncNow() } }
        }
    }

    /// One-time, non-destructive combine of duplicate saved deals. Guarded by a
    /// flag so it runs at most once; the merge is idempotent regardless.
    private func backfillDuplicatesOnce() {
        let flag = "didMergeDuplicateDeals.v1"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        DealMerger.mergeExisting(in: context)
        try? context.save()
        UserDefaults.standard.set(true, forKey: flag)
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container)
}
