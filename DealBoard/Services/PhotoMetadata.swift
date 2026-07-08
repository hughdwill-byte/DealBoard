import ImageIO
import CoreLocation
import Photos

/// Pulls a coordinate out of an imported photo. PhotosPicker can hand back a
/// copy with the GPS stripped, so we try two sources in order:
///   1. EXIF GPS embedded in the original image data (offline, no permission).
///   2. The backing PHAsset's `.location` (needs photo-library access).
/// Returns nil if neither yields a coordinate — the caller then falls back to
/// manual establishment entry.
enum PhotoMetadata {
    /// Parse kCGImagePropertyGPSDictionary out of raw image data via ImageIO.
    static func coordinate(fromImageData data: Data) -> CLLocationCoordinate2D? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              var lat = gps[kCGImagePropertyGPSLatitude] as? Double,
              var lon = gps[kCGImagePropertyGPSLongitude] as? Double
        else { return nil }

        // GPS magnitudes are unsigned; the ref letter carries the sign.
        if let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String, latRef == "S" { lat = -lat }
        if let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String, lonRef == "W" { lon = -lon }

        guard CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lon)) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Fallback: look up the asset by local identifier and read its saved location.
    /// Only works if the user grants read access; silently returns nil otherwise.
    static func coordinate(fromAssetIdentifier identifier: String?) async -> CLLocationCoordinate2D? {
        guard let identifier else { return nil }

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let granted: Bool
        if status == .notDetermined {
            granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite) == .authorized
                || PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited
        } else {
            granted = status == .authorized || status == .limited
        }
        guard granted else { return nil }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return assets.firstObject?.location?.coordinate
    }
}
