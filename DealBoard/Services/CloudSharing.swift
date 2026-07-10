import Foundation
import SwiftData
import SwiftUI

/// Optional cloud sharing: friends join a "board" with a short code and their
/// deals stay in sync via Supabase. Strictly additive — with no config, no group,
/// or no connection, the app is 100% local and unchanged.
///
/// Sync is per-record, last-write-wins on `updatedAt`, so two people adding
/// different deals both keep them (only edits to the *same* record can clobber).
/// v1 syncs deal data and establishments; photos stay on-device.
@MainActor
final class CloudSharing: ObservableObject {
    static let shared = CloudSharing()

    enum Status: Equatable {
        case idle, syncing, synced(Date), error(String)
    }

    @Published private(set) var groupCode: String?
    @Published private(set) var status: Status = .idle

    /// Set once at launch so the engine can read/write the local store.
    var context: ModelContext?

    private var syncTask: Task<Void, Never>?

    var isSharing: Bool { groupCode != nil && CloudConfig.isConfigured }

    private init() {
        groupCode = UserDefaults.standard.string(forKey: "cloudGroupCode")
    }

    // MARK: Group membership

    func createGroup() async {
        let code = Self.makeCode()
        setGroup(code, resetForShareAll: true)
        await syncNow()
    }

    func join(code raw: String) async {
        let code = raw.uppercased().trimmingCharacters(in: .whitespaces)
        guard code.count >= 4 else { status = .error("That code looks too short."); return }
        setGroup(code, resetForShareAll: true)
        await syncNow()
    }

    func leave() {
        syncTask?.cancel()
        groupCode = nil
        status = .idle
        UserDefaults.standard.removeObject(forKey: "cloudGroupCode")
    }

    private func setGroup(_ code: String, resetForShareAll: Bool) {
        groupCode = code
        UserDefaults.standard.set(code, forKey: "cloudGroupCode")
        if resetForShareAll {
            // Push everything local and pull everything remote → converge.
            setStamp("lastPushed", code, .distantPast)
            setStamp("lastPulled", code, .distantPast)
        }
    }

    // MARK: Sync

    /// Debounced background sync after a local edit.
    func scheduleSync() {
        guard isSharing else { return }
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    func syncNow() async {
        guard isSharing, let code = groupCode, let context, let api = SupabaseREST() else { return }
        status = .syncing
        do {
            try await push(code: code, api: api, context: context)
            try await pull(code: code, api: api, context: context)
            try? context.save()
            status = .synced(Date())
        } catch is CancellationError {
            status = .idle
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    // MARK: Push (local → cloud)

    private func push(code: String, api: SupabaseREST, context: ModelContext) async throws {
        let since = stamp("lastPushed", code)
        let start = Date()

        let places = try context.fetch(FetchDescriptor<Establishment>())
            .filter { $0.updatedAt > since }
        try await api.upsert(table: "shared_establishments",
                             rows: places.map { row(for: $0, code: code) })

        let deals = try context.fetch(FetchDescriptor<Deal>())
            .filter { $0.updatedAt > since }
        try await api.upsert(table: "shared_deals",
                             rows: deals.map { row(for: $0, code: code) })

        setStamp("lastPushed", code, start)
    }

    // MARK: Pull (cloud → local)

    private func pull(code: String, api: SupabaseREST, context: ModelContext) async throws {
        let since = stamp("lastPulled", code)
        var newest = since

        // Establishments first so deals can link to them.
        let placeRows = try await api.fetch(table: "shared_establishments", groupCode: code, since: since)
        var placesByID = Dictionary(uniqueKeysWithValues:
            try context.fetch(FetchDescriptor<Establishment>()).map { ($0.id, $0) })
        for r in placeRows {
            guard let id = uuid(r["id"]), let updated = date(r["updated_at"]) else { continue }
            newest = max(newest, updated)
            let existing = placesByID[id]
            if let existing, existing.updatedAt > updated { continue }   // local newer
            let place = existing ?? {
                let p = Establishment(); p.id = id; context.insert(p); placesByID[id] = p; return p
            }()
            apply(row: r, to: place, updated: updated)
        }

        let dealRows = try await api.fetch(table: "shared_deals", groupCode: code, since: since)
        let dealsByID = Dictionary(uniqueKeysWithValues:
            try context.fetch(FetchDescriptor<Deal>()).map { ($0.id, $0) })
        for r in dealRows {
            guard let id = uuid(r["id"]), let updated = date(r["updated_at"]) else { continue }
            newest = max(newest, updated)
            let existing = dealsByID[id]
            if let existing, existing.updatedAt > updated { continue }   // local newer
            let deal = existing ?? { let d = Deal(); d.id = id; context.insert(d); return d }()
            apply(row: r, to: deal, updated: updated, placesByID: placesByID)
        }

        setStamp("lastPulled", code, newest)
    }

    // MARK: Row encoding

    private func row(for d: Deal, code: String) -> [String: Any] {
        var payload: [String: Any] = [
            "title": d.title, "keyPoints": d.keyPoints, "rawText": d.rawText,
            "dealTypeRaw": d.dealTypeRaw, "weekdays": d.weekdays,
            "timeSlots": d.timeSlots.map { slot -> [String: Any] in
                var s: [String: Any] = [:]
                s["startMinutes"] = slot.startMinutes
                s["endMinutes"] = slot.endMinutes
                s["price"] = slot.price
                return s
            },
            "dateAdded": SupabaseREST.iso.string(from: d.dateAdded)
        ]
        payload["notes"] = d.notes
        payload["otherDescription"] = d.otherDescription
        payload["price"] = d.price
        payload["startMinutes"] = d.startMinutes
        payload["endMinutes"] = d.endMinutes
        payload["establishmentID"] = d.establishment?.id.uuidString
        return baseRow(id: d.id, code: code, updated: d.updatedAt, deleted: d.isDeleted, payload: payload)
    }

    private func row(for e: Establishment, code: String) -> [String: Any] {
        var payload: [String: Any] = ["name": e.name]
        payload["specials"] = e.specials
        payload["address"] = e.address
        payload["latitude"] = e.latitude
        payload["longitude"] = e.longitude
        payload["notes"] = e.notes
        return baseRow(id: e.id, code: code, updated: e.updatedAt, deleted: e.isDeleted, payload: payload)
    }

    private func baseRow(id: UUID, code: String, updated: Date, deleted: Bool, payload: [String: Any]) -> [String: Any] {
        ["id": id.uuidString.lowercased(), "group_code": code,
         "updated_at": SupabaseREST.iso.string(from: updated),
         "is_deleted": deleted, "payload": payload]
    }

    // MARK: Row decoding

    private func apply(row r: [String: Any], to d: Deal, updated: Date, placesByID: [UUID: Establishment]) {
        let p = (r["payload"] as? [String: Any]) ?? [:]
        d.title = p["title"] as? String ?? ""
        d.keyPoints = p["keyPoints"] as? String ?? ""
        d.rawText = p["rawText"] as? String ?? ""
        d.dealTypeRaw = p["dealTypeRaw"] as? String ?? DealType.food.rawValue
        d.weekdays = (p["weekdays"] as? [Int]) ?? []
        d.notes = p["notes"] as? String
        d.otherDescription = p["otherDescription"] as? String
        d.price = p["price"] as? String
        d.startMinutes = p["startMinutes"] as? Int
        d.endMinutes = p["endMinutes"] as? Int
        d.timeSlots = ((p["timeSlots"] as? [[String: Any]]) ?? []).map { s in
            TimeSlot(startMinutes: s["startMinutes"] as? Int,
                     endMinutes: s["endMinutes"] as? Int,
                     price: s["price"] as? String)
        }
        if let eid = (p["establishmentID"] as? String).flatMap(UUID.init(uuidString:)) {
            d.establishment = placesByID[eid]
        }
        d.isDeleted = (r["is_deleted"] as? Bool) ?? false
        d.updatedAt = updated
    }

    private func apply(row r: [String: Any], to e: Establishment, updated: Date) {
        let p = (r["payload"] as? [String: Any]) ?? [:]
        e.name = p["name"] as? String ?? ""
        e.specials = p["specials"] as? String
        e.address = p["address"] as? String
        e.latitude = p["latitude"] as? Double
        e.longitude = p["longitude"] as? Double
        e.notes = p["notes"] as? String
        e.isDeleted = (r["is_deleted"] as? Bool) ?? false
        e.updatedAt = updated
    }

    // MARK: Helpers

    private func uuid(_ v: Any?) -> UUID? { (v as? String).flatMap(UUID.init(uuidString:)) }
    private func date(_ v: Any?) -> Date? { (v as? String).flatMap(SupabaseREST.parseDate) }

    private func stamp(_ kind: String, _ code: String) -> Date {
        UserDefaults.standard.object(forKey: "\(kind).\(code)") as? Date ?? .distantPast
    }
    private func setStamp(_ kind: String, _ code: String, _ date: Date) {
        UserDefaults.standard.set(date, forKey: "\(kind).\(code)")
    }

    /// Six characters from an unambiguous alphabet (no O/0, I/1).
    static func makeCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }
}
