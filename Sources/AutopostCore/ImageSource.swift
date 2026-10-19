import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageSourceError: LocalizedError {
    case unreadable(URL)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let url): "Could not read \(url.lastPathComponent)."
        }
    }
}

/// One photo on disk, opened through ImageIO. Handles JPEG, HEIC, TIFF and camera RAW alike.
public struct ImageSource {
    private let source: CGImageSource
    public let url: URL
    public let properties: [CFString: Any]

    public init(url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { throw ImageSourceError.unreadable(url) }

        self.source = source
        self.url = url
        self.properties = properties
    }

    public static func isSupported(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }

    /// The photo scaled so its long edge is at most `maxPixelSize`, upright and in its own color space.
    ///
    /// A preview may come from the embedded JPEG in a RAW file, which is fast. An export always decodes the full image.
    public func image(maxPixelSize: Int, isPreview: Bool = false) -> CGImage? {
        let options: [CFString: Any] = [
            isPreview ? kCGImageSourceCreateThumbnailFromImageIfAbsent : kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Full size in display orientation, so a portrait shot reads as taller than wide.
    public var pixelSize: CGSize {
        let width = properties[kCGImagePropertyPixelWidth] as? Double ?? 0
        let height = properties[kCGImagePropertyPixelHeight] as? Double ?? 0
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        // EXIF orientations 5 to 8 rotate by 90 degrees.
        return orientation >= 5 ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
    }

    /// "SONY ILCE-7M4 · 35mm · ƒ/2 · 1/250s · ISO 100", or nil for scans and screenshots with no camera data.
    public var exifLine: String? {
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        var parts: [String] = []

        if let model = tiff[kCGImagePropertyTIFFModel] as? String {
            parts.append(model.trimmingCharacters(in: .whitespaces))
        }
        if let focal = exif[kCGImagePropertyExifFocalLength] as? Double {
            parts.append("\(Int(focal.rounded()))mm")
        }
        if let aperture = exif[kCGImagePropertyExifFNumber] as? Double {
            parts.append("ƒ/\(aperture.formatted(.number.precision(.fractionLength(0...1))))")
        }
        if let exposure = exif[kCGImagePropertyExifExposureTime] as? Double, exposure > 0 {
            parts.append(Self.shutterLabel(exposure))
        }
        if let isos = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int], let iso = isos.first {
            parts.append("ISO \(iso)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
    }

    /// 0.004 -> "1/250s", 2.5 -> "2.5s".
    static func shutterLabel(_ seconds: Double) -> String {
        if seconds >= 1 {
            return "\(seconds.formatted(.number.precision(.fractionLength(0...1))))s"
        }
        return "1/\(Int((1 / seconds).rounded()))s"
    }

    /// The metadata to carry into an export. Orientation is reset because the pixels are already upright.
    public func exportMetadata(stripsLocation: Bool) -> [CFString: Any] {
        var metadata: [CFString: Any] = [kCGImagePropertyOrientation: 1]

        var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        tiff[kCGImagePropertyTIFFOrientation] = 1
        metadata[kCGImagePropertyTIFFDictionary] = tiff

        if var exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            // The original pixel dimensions no longer describe the framed image.
            exif[kCGImagePropertyExifPixelXDimension] = nil
            exif[kCGImagePropertyExifPixelYDimension] = nil
            metadata[kCGImagePropertyExifDictionary] = exif
        }
        if let iptc = properties[kCGImagePropertyIPTCDictionary] {
            metadata[kCGImagePropertyIPTCDictionary] = iptc
        }
        if !stripsLocation, let gps = properties[kCGImagePropertyGPSDictionary] {
            metadata[kCGImagePropertyGPSDictionary] = gps
        }

        return metadata
    }
}
