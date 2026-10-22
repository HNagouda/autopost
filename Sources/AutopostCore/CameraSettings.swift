import Foundation

/// The camera settings printed in the caption, each already written the way it prints: "35mm", "ƒ/2", "1/250s", "ISO 100".
///
/// The same type holds what the EXIF says and what the user typed over it for one photo. In the overrides, nil means
/// "use the EXIF", which is also how a film scan with no EXIF gets its settings: every field is typed in.
public struct CameraSettings: Codable, Equatable, Sendable {
    public var camera: String?
    public var focalLength: String?
    public var aperture: String?
    public var shutter: String?
    public var iso: String?

    public init(camera: String? = nil, focalLength: String? = nil, aperture: String? = nil, shutter: String? = nil, iso: String? = nil) {
        self.camera = camera
        self.focalLength = focalLength
        self.aperture = aperture
        self.shutter = shutter
        self.iso = iso
    }

    public var isEmpty: Bool { self == CameraSettings() }

    /// "Sony a6400  ·  35mm  ·  ƒ/2  ·  1/250s  ·  ISO 100", or nil when there is nothing to print.
    public var line: String? {
        let parts = [camera, focalLength, aperture, shutter, iso]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
    }

    /// These settings with every field the overrides fill in replaced. Blank overrides count as not filled in.
    public func overridden(by overrides: CameraSettings) -> CameraSettings {
        CameraSettings(
            camera: Self.filled(overrides.camera) ?? camera,
            focalLength: Self.filled(overrides.focalLength) ?? focalLength,
            aperture: Self.filled(overrides.aperture) ?? aperture,
            shutter: Self.filled(overrides.shutter) ?? shutter,
            iso: Self.filled(overrides.iso) ?? iso
        )
    }

    private static func filled(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return text
    }
}

extension Photo {
    /// What this photo's caption prints in camera settings mode: the EXIF with the camera renamed
    /// (ILCE-6400 to Sony a6400, say), then the photo's own typed settings on top.
    public func cameraSettings(exif: CameraSettings, cameraNames: [String: String]) -> CameraSettings {
        var renamed = exif
        if let model = exif.camera, let name = cameraNames[model], !name.trimmingCharacters(in: .whitespaces).isEmpty {
            renamed.camera = name
        }
        return renamed.overridden(by: cameraOverrides)
    }
}
