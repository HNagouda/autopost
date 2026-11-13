import AutopostCore
import CoreGraphics
import Foundation
import Observation

/// Preview-sized copies of each photo, decoded once off the main thread and shared by every view.
@MainActor @Observable
final class ThumbnailStore {
    // Sharp enough for a large tile and the phone preview on a Retina screen, small enough to keep many in memory.
    nonisolated private static let maxPixelSize = 1200
    // The photo editor fills most of the screen; these are large, so only the last few are kept.
    nonisolated private static let largeMaxPixelSize = 2800
    private static let keptLargeImages = 6

    struct Thumbnail {
        var image: CGImage
        var exif: CameraSettings

        var size: CGSize { CGSize(width: image.width, height: image.height) }
    }

    private(set) var thumbnails: [URL: Thumbnail] = [:]
    private(set) var largeImages: [URL: Thumbnail] = [:]
    private(set) var missing: Set<URL> = []
    private var loading: Set<URL> = []
    private var largeOrder: [URL] = []

    private struct CroppedKey: Hashable {
        var url: URL
        var isLarge: Bool
    }

    private struct Cropped {
        var source: CGImage
        var crop: CropRect
        var image: CGImage
    }

    // The last cropped copy of each photo. Cropping makes a new image every time, and SwiftUI sends a new image to
    // the screen again, so a view redrawn many times a second while dragging must get the same copy back.
    @ObservationIgnored private var croppedImages: [CroppedKey: Cropped] = [:]

    func thumbnail(for url: URL, isLarge: Bool = false) -> Thumbnail? {
        isLarge ? largeImages[url] ?? thumbnails[url] : thumbnails[url]
    }

    /// The photo's preview with `crop` applied, the same image on every call until the crop or the preview changes.
    func croppedImage(for url: URL, crop: CropRect, isLarge: Bool = false) -> CGImage? {
        let key = CroppedKey(url: url, isLarge: isLarge && largeImages[url] != nil)
        guard let source = (key.isLarge ? largeImages[url] : thumbnails[url])?.image else { return nil }
        guard !crop.isFull else { return source }
        if let cached = croppedImages[key], cached.source === source, cached.crop == crop { return cached.image }
        guard let image = source.cropped(to: crop) else { return nil }

        croppedImages[key] = Cropped(source: source, crop: crop, image: image)
        return image
    }

    func loadLarge(_ url: URL) async {
        await load(url)
        guard largeImages[url] == nil else { return }

        let result = await Task.detached(priority: .userInitiated) { () -> Thumbnail? in
            guard let source = try? ImageSource(url: url),
                  let image = source.image(maxPixelSize: Self.largeMaxPixelSize, isPreview: false)
            else { return nil }
            return Thumbnail(image: image, exif: source.cameraSettings)
        }.value

        guard let result else { return }
        largeImages[url] = result
        largeOrder.removeAll { $0 == url }
        largeOrder.append(url)
        while largeOrder.count > Self.keptLargeImages {
            let evicted = largeOrder.removeFirst()
            largeImages[evicted] = nil
            croppedImages[CroppedKey(url: evicted, isLarge: true)] = nil
        }
    }

    func load(_ url: URL) async {
        guard thumbnails[url] == nil, !loading.contains(url) else { return }
        loading.insert(url)
        defer { loading.remove(url) }

        let result = await Task.detached(priority: .userInitiated) { () -> Thumbnail? in
            guard let source = try? ImageSource(url: url),
                  let image = source.image(maxPixelSize: Self.maxPixelSize, isPreview: true)
            else { return nil }
            return Thumbnail(image: image, exif: source.cameraSettings)
        }.value

        if let result {
            thumbnails[url] = result
            missing.remove(url)
        } else {
            missing.insert(url)
        }
    }
}
