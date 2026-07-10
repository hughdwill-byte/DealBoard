import Foundation

/// Supabase connection details, read from `Supabase.plist` in the app bundle.
/// If the file is missing or still has placeholder values, cloud sharing is
/// simply disabled and the app runs fully offline — nothing else changes.
///
/// Set up: copy `Supabase.example.plist` to `Supabase.plist`, fill in your
/// project URL and the public `anon` key. The anon key is designed to be shipped
/// in client apps; access is gated by the group code (see README for the caveat).
enum CloudConfig {
    static let url: URL? = value(for: "SupabaseURL").flatMap(URL.init(string:))
    static let anonKey: String? = value(for: "SupabaseAnonKey")

    static var isConfigured: Bool {
        guard let anonKey, url != nil else { return false }
        return !anonKey.isEmpty && !anonKey.contains("YOUR_")
    }

    private static func value(for key: String) -> String? {
        guard let path = Bundle.main.path(forResource: "Supabase", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let raw = dict[key] as? String,
              !raw.isEmpty else { return nil }
        return raw
    }
}
