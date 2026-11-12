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

/// Turns a post into numbered JPEGs, "Post 1/post-1-01.jpg" and onwards, one per slide in carousel order.
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

        // A photo spread over slides writes one file per slide, so numbering counts slides, not photos.
        var slideNumber = 0
        let jobs = post.photos.map { photo in
            let targets = (0..<photo.slideCount).map { _ in
                slideNumber += 1
                return folder.appendingPathComponent(String(format: "%@-%02d.jpg", stem, slideNumber))
            }
            return (photo, targets)
        }
        var finished = 0

        try await withThrowingTaskGroup(of: Void.self) { group in
            var pending = jobs[...]
            for _ in 0..<min(parallelPhotos, pending.count) {
                let (photo, targets) = pending.removeFirst()
                group.addTask { try exportPhoto(photo, to: targets, frame: post.frame(for: photo), settings: settings, cameraNames: cameraNames) }
            }
            for try await _ in group {
                finished += 1
                progress(finished)
                if let (photo, targets) = pending.popFirst() {
                    group.addTask { try exportPhoto(photo, to: targets, frame: post.frame(for: photo), settings: settings, cameraNames: cameraNames) }
                }
            }
        }

        return jobs.flatMap(\.1)
    }

    /// Writes the photo's slides to `targets`, one file per slide, in order.
    public static func exportPhoto(
        _ photo: Photo, to targets: [URL], frame: FrameSettings, settings: ExportSettings, cameraNames: [String: String]
    ) throws {
        let sources = try photo.images.map { try ImageSource(url: $0.url) }
        let caption = frame.caption(exifLine: photo.cameraSettings(exif: sources[0].cameraSettings, cameraNames: cameraNames).line)
        let croppedSizes = zip(photo.images, sources).map { image, source in image.crop.size(of: source.pixelSize) }
        let width = canvasWidth(for: photo, croppedSizes: croppedSizes, frame: frame, size: settings.size, hasCaption: caption != nil)

        // Decode each whole photo at the scale its kept part needs on the canvas, then cut the crop out of it.
        let planned = FrameLayout(photo: photo, imageSizes: croppedSizes, frame: frame, canvasWidth: width, hasCaption: caption != nil)
        let images = try zip(photo.images, sources).enumerated().map { index, pair in
            let (image, source) = pair
            let scale = fillScale(croppedSizes[index], into: planned.imageRects[index])
            let longEdge = Int((max(source.pixelSize.width, source.pixelSize.height) * scale).rounded(.up))
            guard let decoded = source.image(maxPixelSize: longEdge), let cropped = decoded.cropped(to: image.crop)
            else { throw ImageSourceError.unreadable(image.url) }
            return cropped
        }

        // RAW files can report a slightly different size than they decode to; lay out on the real pixels.
        let decodedSizes = images.map { CGSize(width: $0.width, height: $0.height) }
        let layout = FrameLayout(photo: photo, imageSizes: decodedSizes, frame: frame, canvasWidth: width, hasCaption: caption != nil)
        guard let framed = FrameRenderer.render(
            images: images, layout: layout, frame: frame, caption: caption, textBoxes: photo.textBoxes, isSharpening: settings.isSharpening
        ) else { throw ExportError.renderFailed(photo.url) }

        let metadata = settings.keepsMetadata ? sources[0].exportMetadata(stripsLocation: settings.stripsLocation) : [:]
        for (index, target) in targets.enumerated() {
            let slide = layout.slideCount > 1 ? FrameRenderer.slide(index, of: framed, layout: layout) : framed
            guard let slide else { throw ExportError.renderFailed(photo.url) }
            try writeJPEG(slide, to: target, quality: settings.quality, metadata: metadata)
        }
    }

    /// How much a photo of `size` is scaled to cover `rect`.
    private static func fillScale(_ size: CGSize, into rect: CGRect) -> Double {
        max(rect.width / max(size.width, 1), rect.height / max(size.height, 1))
    }

    /// The width of one slide in pixels; full resolution keeps the top photo at its native size inside the frame.
    static func canvasWidth(for photo: Photo, croppedSizes: [CGSize], frame: FrameSettings, size: ExportSize, hasCaption: Bool) -> Double {
        if let fixed = size.fixedWidth { return Double(fixed) }

        let unit = FrameLayout(photo: photo, imageSizes: croppedSizes, frame: frame, canvasWidth: 1, hasCaption: hasCaption)
        return min((1 / fillScale(croppedSizes[0], into: unit.imageRects[0])).rounded(), maxCanvasWidth)
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
