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
        _ post: Post, settings: ExportSettings, progress: @escaping @Sendable (Int) -> Void
    ) async throws -> [URL] {
        let folder = folder(for: post, settings: settings)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stem = slug(post.name)
        try removePreviousExports(in: folder, stem: stem)

        let jobs = post.photos.enumerated().map { index, photo in
            (photo.url, folder.appendingPathComponent(String(format: "%@-%02d.jpg", stem, index + 1)))
        }
        var finished = 0

        try await withThrowingTaskGroup(of: Void.self) { group in
            var pending = jobs[...]
            for _ in 0..<min(parallelPhotos, pending.count) {
                let (source, target) = pending.removeFirst()
                group.addTask { try exportPhoto(source, to: target, frame: post.frame, settings: settings) }
            }
            for try await _ in group {
                finished += 1
                progress(finished)
                if let (source, target) = pending.popFirst() {
                    group.addTask { try exportPhoto(source, to: target, frame: post.frame, settings: settings) }
                }
            }
        }

        return jobs.map(\.1)
    }

    public static func exportPhoto(_ url: URL, to target: URL, frame: FrameSettings, settings: ExportSettings) throws {
        let source = try ImageSource(url: url)
        let caption = frame.caption(exifLine: source.exifLine)
        let width = canvasWidth(for: source.pixelSize, frame: frame, size: settings.size, hasCaption: caption != nil)

        let planned = FrameLayout(imageSize: source.pixelSize, frame: frame, canvasWidth: width, hasCaption: caption != nil)
        let longEdge = Int(max(planned.imageRect.width, planned.imageRect.height).rounded(.up))
        guard let image = source.image(maxPixelSize: longEdge) else { throw ImageSourceError.unreadable(url) }

        // RAW files can report a slightly different size than they decode to; lay out on the real pixels.
        let decodedSize = CGSize(width: image.width, height: image.height)
        let layout = FrameLayout(imageSize: decodedSize, frame: frame, canvasWidth: width, hasCaption: caption != nil)
        guard let framed = FrameRenderer.render(image: image, layout: layout, frame: frame, caption: caption, isSharpening: settings.isSharpening)
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

    static func safeFileName(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return cleaned.trimmingCharacters(in: .whitespaces).isEmpty ? "Post" : cleaned
    }
}
