import SwiftData
import Foundation

/// In-memory container with mock data for SwiftUI #Previews only.
/// The shipping app seeds nothing — this is never used at runtime.
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Deal.self, Establishment.self, configurations: config
        )
        let ctx = container.mainContext

        let cantina = Establishment(name: "El Corazón Cantina", address: "12 Market St")
        let vine = Establishment(name: "The Old Vine", address: "8 Harbour Rd")
        ctx.insert(cantina)
        ctx.insert(vine)

        ctx.insert(Deal(
            title: "Taco Tuesday",
            keyPoints: "$2 street tacos\nAll night",
            dealType: .food,
            weekdays: [3],
            price: "$2",
            establishment: cantina
        ))
        ctx.insert(Deal(
            title: "Half-price Wine Wednesday",
            keyPoints: "50% off all bottles",
            dealType: .drink,
            weekdays: [4],
            price: "50% off",
            establishment: vine
        ))
        ctx.insert(Deal(
            title: "Weekend Bottomless Brunch",
            keyPoints: "Food + drinks\nSat & Sun 11–2",
            dealType: .both,
            weekdays: [1, 7],
            price: "$35",
            establishment: vine
        ))
        return container
    }()
}

extension ModelContext {
    /// Convenience for previews: grab any one deal to drive a detail view.
    var firstDeal: Deal {
        (try? fetch(FetchDescriptor<Deal>()))?.first ?? Deal(title: "Sample")
    }
}
