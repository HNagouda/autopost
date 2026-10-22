import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ExportError: LocalizedError {
    case renderFailed(URL)
    case writeFailed(URL)

    public var errorDescription: String? {
        switch self {
        case .renderFailed(let url): "Could not render \(url.lastPathComponent)."
        case .writeFailed(let url): "Could not write \(url.lastPathComponent)."
        }
    }
}

/// Turns a post into numbered JPEGs, "Post 1/post-1-01.jpg" and onwards, in carousel order.
public enum PostExporter {
    // RAW decodes take a lot of memory; a few at a time keeps a 20-photo carousel from swapping.
    static let parallelPhotos = 4
    // Full-resolution exports from a tiny border could otherwise ask for an absurd canvas.
    static let maxCanvasWidth = 12_000.0

    public static func folder(for post: Post, settings: ExportSettings) -> URL {
        settings.destination.appendingPathComponent(safeFileName(post.name), isDirectory: true)
    }

    public static func export(
        _ post: Post, settings: ExportSettings, cameraNames: [String: String], progress: @escaping @Sendable (Int) -> Void
    ) async throws -> [URL] {
        let folder = folder(for: post, settings: settings)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stem = slug(post.name)
        try removePreviousExports(in: folder, stem: stem)

        let jobs = post.photos.enumerated().map { index, photo in
            (photo, folder.appendingPathComponent(String(format: "%@-%02d.jpg", stem, index + 1)))
        }
        var finished = 0

        try await withThrowingTaskGroup(of: Void.self) { group in
            var pending = jobs[...]
            for _ in 0..<min(parallelPhotos, pending.count) {
                let (photo, target) = pending.removeFirst()
                group.addTask { try exportPhoto(photo, to: target, frame: post.frame(for: photo), settings: settings, cameraNames: cameraNames) }
            }
            for try await _ in group {
                finished += 1
                progress(finished)
                if let (photo, target) = pending.popFirst() {
                    group.addTask { try exportPhoto(photo, to: target, frame: post.frame(for: photo), settings: settings, cameraNames: cameraNames) }
                }
            }
        }

        return jobs.map(\.1)
    }

    public static func exportPhoto(
        _ photo: Photo, to target: URL, frame: FrameSettings, settings: ExportSettings, cameraNames: [String: String]
    ) throws {
        let url = photo.url
        let source = try ImageSource(url: url)
        let caption = frame.caption(exifLine: photo.cameraSettings(exif: source.cameraSettings, cameraNames: cameraNames).line)
        let croppedSize = photo.crop.size(of: source.pixelSize)
        let width = canvasWidth(for: croppedSize, frame: frame, size: settings.size, hasCaption: caption != nil)

        // Decode the whole photo at the scale the kept part needs on the canvas, then cut the crop out of it.
        let planned = FrameLayout(imageSize: croppedSize, frame: frame, canvasWidth: width, hasCaption: caption != nil)
        let scale = planned.imageRect.width / max(croppedSize.width, 1)
        let longEdge = Int((max(source.pixelSize.width, source.pixelSize.height) * scale).rounded(.up))
        guard let decoded = source.image(maxPixelSize: longEdge), let image = decoded.cropped(to: photo.crop)
        else { throw ImageSourceError.unreadable(url) }

        // RAW files can report a slightly different size than they decode to; lay out on the real pixels.
        let decodedSize = CGSize(width: image.width, height: image.height)
        let layout = FrameLayout(imageSize: decodedSize, frame: frame, canvasWidth: width, hasCaption: caption != nil)
        guard let framed = FrameRenderer.render(image: image, layout: layout, frame: frame, caption: caption, textBoxes: photo.textBoxes, isSharpening: settings.isSharpening)
        else { throw ExportError.renderFailed(url) }

        let metadata = settings.keepsMetadata ? source.exportMetadata(stripsLocation: settings.stripsLocation) : [:]
        try writeJPEG(framed, to: target, quality: settings.quality, metadata: metadata)
    }

    /// The canvas width in pixels; full resolution keeps the photo at its native size inside the frame.
    static func canvasWidth(for pixelSize: CGSize, frame: FrameSettings, size: ExportSize, hasCaption: Bool) -> Double {
        if let fixed = size.fixedWidth { return Double(fixed) }

        let unit = FrameLayout(imageSize: pixelSize, frame: frame, canvasWidth: 1, hasCaption: hasCaption)
        return min((pixelSize.width / unit.imageRect.width).rounded(), maxCanvasWidth)
    }

    static func writeJPEG(_ image: CGImage, to url: URL, quality: Double, metadata: [CFString: Any]) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw ExportError.writeFailed(url) }

        var properties = metadata
        properties[kCGImageDestinationLossyCompressionQuality] = quality
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ExportError.writeFailed(url) }
    }

    /// A post that shrank from 8 to 6 photos must not leave 07 and 08 behind. Only our own numbered files go.
    static func removePreviousExports(in folder: URL, stem: String) throws {
        let pattern = try Regex("^\(NSRegularExpression.escapedPattern(for: stem))-\\d{2}\\.jpg$")
        for file in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        where file.lastPathComponent.wholeMatch(of: pattern) != nil {
            try FileManager.default.removeItem(at: file)
        }
    }

    /// "Cali on film #2" -> "cali-on-film-2".
    static func slug(_ name: String) -> String {
        let words = name.lowercased().split { !$0.isLetter && !$0.isNumber }
        return words.isEmpty ? "post" : words.joined(separator: "-")
    }

    /// "Trip/1" -> "Trip-1", ".." -> "Post".
    static func safeFileName(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        // Leading dots would hide the folder, and a name of only dots would point outside the export folder.
        let visible = String(cleaned.drop { $0 == "." }).trimmingCharacters(in: .whitespaces)
        return visible.isEmpty ? "Post" : visible
    }
}
