import Foundation
import SwiftData

/// Combines repeated versions of the same deal (same place, same day, same
/// title/type/details) into a single deal that holds multiple time+price slots.
///
/// Two entry points:
///  - `mergeExisting(in:)` — one-time backfill over already-saved deals.
///  - `slots(forNew:matching:)` helpers via `identityKey` — used when saving a
///    new deal so future duplicates fold into the existing one instead of piling
///    up. Both are idempotent: once combined, nothing re-combines on its own.
enum DealMerger {

    /// Identity of a deal for combining: everything that must match, i.e. place,
    /// days, title, type and all key details — but NOT time or price. Deals with
    /// the same key are "the same deal" and may be combined.
    static func identityKey(_ deal: Deal) -> String {
        identityKey(
            establishmentID: deal.establishment?.id,
            weekdays: deal.weekdays,
            title: deal.title,
            dealTypeRaw: deal.dealTypeRaw,
            keyPoints: deal.keyPoints,
            notes: deal.notes,
            otherDescription: deal.otherDescription
        )
    }

    /// Same key built from raw fields, so a not-yet-saved deal can be matched
    /// without constructing a throwaway model object.
    static func identityKey(
        establishmentID: UUID?, weekdays: [Int], title: String, dealTypeRaw: String,
        keyPoints: String, notes: String?, otherDescription: String?
    ) -> String {
        [
            establishmentID?.uuidString ?? "no-place",
            weekdays.sorted().map(String.init).joined(separator: ","),
            norm(title),
            dealTypeRaw,
            norm(keyPoints),
            norm(notes ?? ""),
            norm(otherDescription ?? "")
        ].joined(separator: "\u{1f}")   // unit separator, won't appear in text
    }

    private static func norm(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Append `newSlots` to `existing`, dropping any that duplicate a window it
    /// already has (so re-adding the same time/price is a no-op).
    static func combinedSlots(existing: [TimeSlot], adding newSlots: [TimeSlot]) -> [TimeSlot] {
        var result = existing
        for slot in newSlots where !result.contains(where: { $0.sameContent(as: slot) }) {
            result.append(slot)
        }
        return result
    }

    /// One-time backfill: fold duplicate saved deals into combined deals.
    /// Returns how many duplicate rows were removed. Safe to call repeatedly —
    /// after the first pass no duplicate keys remain, so further calls do nothing.
    @discardableResult
    static func mergeExisting(in context: ModelContext) -> Int {
        let deals = (try? context.fetch(FetchDescriptor<Deal>())) ?? []

        var groups: [String: [Deal]] = [:]
        for deal in deals { groups[identityKey(deal), default: []].append(deal) }

        var removed = 0
        for group in groups.values where group.count > 1 {
            // Keep the oldest as canonical; fold the rest of the windows into it.
            let ordered = group.sorted { $0.dateAdded < $1.dateAdded }
            let canonical = ordered[0]
            var slots = canonical.orderedSlots

            for duplicate in ordered.dropFirst() {
                slots = combinedSlots(existing: slots, adding: duplicate.orderedSlots)
                // Preserve a photo if the canonical hasn't got one; otherwise the
                // duplicate's photo file is redundant, so remove it.
                if canonical.imageFilename == nil, let file = duplicate.imageFilename {
                    canonical.imageFilename = file
                } else if let file = duplicate.imageFilename {
                    ImageStore.delete(file)
                }
                context.delete(duplicate)
                removed += 1
            }

            canonical.timeSlots = slots
            syncLegacyFields(of: canonical)
        }
        return removed
    }

    /// Keep the legacy single-window fields in step with the first slot so any
    /// code still reading them stays correct.
    static func syncLegacyFields(of deal: Deal) {
        let first = deal.orderedSlots.first
        deal.startMinutes = first?.startMinutes
        deal.endMinutes = first?.endMinutes
        deal.price = first?.price
    }
}
