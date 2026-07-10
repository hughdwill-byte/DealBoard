import Foundation

/// Tiny PostgREST client for Supabase — just the two calls sync needs: a
/// filtered select and an upsert. Uses the public anon key; all failures throw
/// so the caller can degrade gracefully (offline-first is preserved).
struct SupabaseREST {
    let baseURL: URL
    let anonKey: String

    init?() {
        guard let url = CloudConfig.url, let key = CloudConfig.anonKey, CloudConfig.isConfigured
        else { return nil }
        self.baseURL = url
        self.anonKey = key
    }

    private func request(path: String, query: [URLQueryItem] = []) -> URLRequest {
        var comps = URLComponents(url: baseURL.appendingPathComponent("rest/v1/\(path)"),
                                  resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 20
        return req
    }

    /// Rows in `table` for a group updated strictly after `since`, oldest first.
    func fetch(table: String, groupCode: String, since: Date) async throws -> [[String: Any]] {
        var req = request(path: table, query: [
            URLQueryItem(name: "group_code", value: "eq.\(groupCode)"),
            URLQueryItem(name: "updated_at", value: "gt.\(Self.iso.string(from: since))"),
            URLQueryItem(name: "order", value: "updated_at.asc")
        ])
        req.httpMethod = "GET"
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.check(resp, data)
        return (try JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }

    /// Insert or update rows, matching on the primary key `id`.
    func upsert(table: String, rows: [[String: Any]]) async throws {
        guard !rows.isEmpty else { return }
        var req = request(path: table)
        req.httpMethod = "POST"
        req.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONSerialization.data(withJSONObject: rows)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.check(resp, data)
    }

    private static func check(_ resp: URLResponse, _ data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "SupabaseREST", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"])
        }
    }

    /// For encoding outgoing timestamps (fractional seconds; Postgres accepts it).
    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Parse a Supabase timestamp, which may or may not carry fractional seconds.
    static func parseDate(_ string: String) -> Date? {
        iso.date(from: string) ?? isoPlain.date(from: string)
    }
}
