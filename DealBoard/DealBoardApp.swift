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
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Deals", systemImage: "calendar") }
            EstablishmentsView()
                .tabItem { Label("Places", systemImage: "mappin.and.ellipse") }
        }
        .tint(Theme.accent)
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container)
}
