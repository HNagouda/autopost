import CoreGraphics
import Foundation
import ImageIO

/// What a photo file says about itself, for the Info section of an open photo. Every field is nil when the file
/// does not carry it, as with scans and screenshots.
public struct PhotoInfo: Equatable, Sendable {
    public var pixelSize: CGSize
    public var fileSize: Int?
    // When the shutter fired, as the camera's clock read it. EXIF stores no time zone, so this is read and shown
    // in UTC, which prints the camera's own wall-clock time unchanged wherever the Mac is.
    public var takenAt: Date?
    public var camera: String?
    public var lens: String?
    public var latitude: Double?
    public var longitude: Double?
    // The place name the photographer or their software wrote in, like "Bled, Slovenia".
    public var place: String?

    public init(properties: [CFString: Any], pixelSize: CGSize, fileSize: Int?) {
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] ?? [:]
        let iptc = properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any] ?? [:]

        self.pixelSize = pixelSize
        self.fileSize = fileSize
        takenAt = (exif[kCGImagePropertyExifDateTimeOriginal] as? String).flatMap(Self.exifDate)
        camera = Self.joined(tiff[kCGImagePropertyTIFFMake] as? String, tiff[kCGImagePropertyTIFFModel] as? String)
        lens = (exif[kCGImagePropertyExifLensModel] as? String)?.trimmingCharacters(in: .whitespaces)
        latitude = Self.coordinate(gps[kCGImagePropertyGPSLatitude], reference: gps[kCGImagePropertyGPSLatitudeRef], negative: "S")
        longitude = Self.coordinate(gps[kCGImagePropertyGPSLongitude], reference: gps[kCGImagePropertyGPSLongitudeRef], negative: "W")
        let names = [kCGImagePropertyIPTCCity, kCGImagePropertyIPTCProvinceState, kCGImagePropertyIPTCCountryPrimaryLocationName]
            .compactMap { iptc[$0] as? String }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        place = names.isEmpty ? nil : names.joined(separator: ", ")
    }

    /// Reads the file's metadata without decoding the pixels.
    public init(url: URL) throws {
        let source = try ImageSource(url: url)
        let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        self.init(properties: source.properties, pixelSize: source.pixelSize, fileSize: fileSize)
    }

    /// 6000 × 4000 -> 24.0.
    public var megapixels: Double {
        pixelSize.width * pixelSize.height / 1_000_000
    }

    // Sensor sizes are rarely an exact ratio (6048 × 4024 is 1.503), so a ratio this close counts as the named one.
    private static let ratioTolerance = 0.01

    /// 6000 × 4000 -> "3:2", 4000 × 6000 -> "2:3", 7000 × 3000 -> "2.33:1", using the ratios the ratio picker offers.
    public var ratioLabel: String {
        let ratio = pixelSize.width / max(pixelSize.height, 1)
        let isPortrait = ratio < 1
        let wide = isPortrait ? 1 / ratio : ratio

        let named = AspectRatio.allCases.first { candidate in
            guard let value = candidate.fixedValue, value >= 1 else { return false }
            return abs(value - wide) / value < Self.ratioTolerance
        }
        // A point, never a comma, to match the "1.91:1" the ratio picker shows in every language.
        let decimal = wide.formatted(FloatingPointFormatStyle<Double>(locale: Locale(identifier: "en_US_POSIX")).precision(.fractionLength(0...2)))
        let sides = named.map { $0.label.split(separator: ":").map(String.init) } ?? [decimal, "1"]

        return isPortrait ? "\(sides[1]):\(sides[0])" : "\(sides[0]):\(sides[1])"
    }

    /// "Sat 14 Sep 2024 at 18:42", the camera's wall-clock time, in the user's own date format.
    public var takenLabel: String? {
        guard let takenAt else { return nil }
        var style = Date.FormatStyle(date: .complete, time: .shortened)
        style.timeZone = .gmt
        return takenAt.formatted(style)
    }

    /// "Canon" and "Canon EOS R5" -> "Canon EOS R5", since most cameras repeat the make in the model.
    private static func joined(_ make: String?, _ model: String?) -> String? {
        let make = make?.trimmingCharacters(in: .whitespaces) ?? ""
        let model = model?.trimmingCharacters(in: .whitespaces) ?? ""
        if model.isEmpty { return make.isEmpty ? nil : make }
        if make.isEmpty || model.lowercased().hasPrefix(make.lowercased()) { return model }
        return "\(make) \(model)"
    }

    /// "2024:09:14 18:42:07" -> that moment, read in UTC.
    private static func exifDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: text)
    }

    /// GPS stores the size of a coordinate and its hemisphere separately; south and west are negative.
    private static func coordinate(_ value: Any?, reference: Any?, negative: String) -> Double? {
        guard let value = value as? Double else { return nil }
        return (reference as? String) == negative ? -value : value
    }
}
