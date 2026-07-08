import UIKit

/// Saves deal photos as JPEG files in the app's Documents directory and loads
/// them back by filename. We reference photos by filename in SwiftData rather
/// than storing the blob in the store — this keeps the database small and the
/// files easy to reason about. Fully offline.
enum ImageStore {
    private static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static func url(for filename: String) -> URL {
        documents.appendingPathComponent(filename)
    }

    /// Persist an image, returning the generated filename to store on the Deal.
    @discardableResult
    static func save(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: url(for: filename), options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    static func load(_ filename: String?) -> UIImage? {
        guard let filename else { return nil }
        return UIImage(contentsOfFile: url(for: filename).path)
    }

    static func delete(_ filename: String?) {
        guard let filename else { return }
        try? FileManager.default.removeItem(at: url(for: filename))
    }
}
