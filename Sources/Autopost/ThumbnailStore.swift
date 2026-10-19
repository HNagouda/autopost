import AutopostCore
import CoreGraphics
import Foundation
import Observation

/// Preview-sized copies of each photo, decoded once off the main thread and shared by every view.
@MainActor @Observable
final class ThumbnailStore {
    // Sharp enough for a large tile and the phone preview on a Retina screen, small enough to keep many in memory.
    nonisolated private static let maxPixelSize = 1200

    struct Thumbnail {
        var image: CGImage
        var exifLine: String?

        var size: CGSize { CGSize(width: image.width, height: image.height) }
    }

    private(set) var thumbnails: [URL: Thumbnail] = [:]
    private(set) var missing: Set<URL> = []
    private var loading: Set<URL> = []

    func thumbnail(for url: URL) -> Thumbnail? {
        thumbnails[url]
    }

    func load(_ url: URL) async {
        guard thumbnails[url] == nil, !loading.contains(url) else { return }
        loading.insert(url)
        defer { loading.remove(url) }

        let result = await Task.detached(priority: .userInitiated) { () -> Thumbnail? in
            guard let source = try? ImageSource(url: url),
                  let image = source.image(maxPixelSize: Self.maxPixelSize, isPreview: true)
            else { return nil }
            return Thumbnail(image: image, exifLine: source.exifLine)
        }.value

        if let result {
            thumbnails[url] = result
            missing.remove(url)
        } else {
            missing.insert(url)
        }
    }
}
