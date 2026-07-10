import SwiftData

/// Deletion that does the right thing for sharing: while in a shared board a
/// delete is a soft-delete (a tombstone that syncs to friends); otherwise it's a
/// plain local delete, exactly as before. Keeps offline behaviour unchanged.
@MainActor
enum DealStore {
    static func delete(_ deal: Deal, in context: ModelContext) {
        if CloudSharing.shared.isSharing {
            deal.isDeleted = true
            deal.touch()
            CloudSharing.shared.scheduleSync()
        } else {
            ImageStore.delete(deal.imageFilename)
            context.delete(deal)
        }
    }

    static func delete(_ place: Establishment, in context: ModelContext) {
        if CloudSharing.shared.isSharing {
            place.isDeleted = true
            place.touch()
            CloudSharing.shared.scheduleSync()
        } else {
            context.delete(place)
        }
    }
}
