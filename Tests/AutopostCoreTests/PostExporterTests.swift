import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import AutopostCore

/// A 300 x 200 JPEG with a GPS position, a written city and a camera serial number.
private func writeSourcePhoto(to url: URL) throws {
    let context = CGContext(
        data: nil, width: 300, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.setFillColor(CGColor(srgbRed: 0.8, green: 0.3, blue: 0.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 300, height: 200))

    let metadata: [CFString: Any] = [
        kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 52.1, kCGImagePropertyGPSLatitudeRef: "N"],
        kCGImagePropertyIPTCDictionary: [kCGImagePropertyIPTCCity: "Zeist", kCGImagePropertyIPTCCopyrightNotice: "Harsh"],
        kCGImagePropertyExifDictionary: [kCGImagePropertyExifBodySerialNumber: "1234567", kCGImagePropertyExifFNumber: 2.8],
    ]
    try PostExporter.writeJPEG(context.makeImage()!, to: url, quality: 0.9, metadata: metadata)
}

private func properties(of url: URL) -> [CFString: Any] {
    let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
    return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]
}

@Test func croppedExportHasTheCropShapeAndNoLocationOrSerialNumber() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let sourceURL = folder.appendingPathComponent("source.jpg")
    try writeSourcePhoto(to: sourceURL)

    var photo = Photo(url: sourceURL)
    photo.crop = CropRect.full.fitted(toShape: 1, imageAspect: 1.5)
    var frame = FrameSettings()
    frame.ratio = .original
    frame.borderPercent = 0
    let target = folder.appendingPathComponent("out.jpg")
    try PostExporter.exportPhoto(photo, to: [target], frame: frame, settings: ExportSettings(), cameraNames: [:])

    let exported = properties(of: target)
    let iptc = exported[kCGImagePropertyIPTCDictionary] as? [CFString: Any] ?? [:]
    let exif = exported[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
    // A square crop with no border at the 1080 px Instagram width.
    #expect(exported[kCGImagePropertyPixelWidth] as? Int == 1080)
    #expect(exported[kCGImagePropertyPixelHeight] as? Int == 1080)
    #expect(exported[kCGImagePropertyGPSDictionary] == nil)
    #expect(iptc[kCGImagePropertyIPTCCity] == nil)
    #expect(iptc[kCGImagePropertyIPTCCopyrightNotice] as? String == "Harsh")
    #expect(exif[kCGImagePropertyExifBodySerialNumber] == nil)
    #expect(exif[kCGImagePropertyExifFNumber] as? Double == 2.8)
}

@Test func panoramaOverTwoSlidesWritesTwoSlidesInCarouselOrder() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let sourceURL = folder.appendingPathComponent("source.jpg")
    try writeSourcePhoto(to: sourceURL)

    var post = Post(name: "Alps", frame: FrameSettings())
    var panorama = Photo(url: sourceURL)
    panorama.slideCount = 2
    post.photos = [panorama, Photo(url: sourceURL)]
    var settings = ExportSettings()
    settings.destination = folder
    let files = try await PostExporter.export(post, settings: settings, cameraNames: [:]) { _ in }

    #expect(files.map(\.lastPathComponent) == ["alps-01.jpg", "alps-02.jpg", "alps-03.jpg"])
    for file in files {
        #expect(properties(of: file)[kCGImagePropertyPixelWidth] as? Int == 1080)
        #expect(properties(of: file)[kCGImagePropertyPixelHeight] as? Int == 1350)
    }
}

@Test func canvasOfThreePhotosExportsOneFilePerSlide() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let sourceURL = folder.appendingPathComponent("source.jpg")
    try writeSourcePhoto(to: sourceURL)

    var post = Post(name: "Alps", frame: FrameSettings())
    let photos = [Photo(url: sourceURL), Photo(url: sourceURL), Photo(url: sourceURL)]
    let canvas = try #require(Photo.canvas(of: photos, template: .overlaySplit, slideRatio: 0.8, seed: 7))
    post.photos = [canvas, Photo(url: sourceURL)]
    var settings = ExportSettings()
    settings.destination = folder
    let files = try await PostExporter.export(post, settings: settings, cameraNames: [:]) { _ in }

    #expect(files.count == canvas.slideCount + 1)
    for file in files {
        #expect(properties(of: file)[kCGImagePropertyPixelWidth] as? Int == 1080)
        #expect(properties(of: file)[kCGImagePropertyPixelHeight] as? Int == 1350)
    }
}

@Test func stackOfTwoPhotosExportsAsOneSlide() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let sourceURL = folder.appendingPathComponent("source.jpg")
    try writeSourcePhoto(to: sourceURL)

    var post = Post(name: "Alps", frame: FrameSettings())
    var stack = Photo(url: sourceURL)
    stack.stacked = [Photo(url: sourceURL)]
    post.photos = [stack]
    var settings = ExportSettings()
    settings.destination = folder
    let files = try await PostExporter.export(post, settings: settings, cameraNames: [:]) { _ in }

    #expect(files.map(\.lastPathComponent) == ["alps-01.jpg"])
    #expect(properties(of: files[0])[kCGImagePropertyPixelHeight] as? Int == 1350)
}

@Test(arguments: [("..", "Post"), (" ..", "Post"), (". ..", "Post"), (".hidden", "hidden"), ("Trip/1", "Trip-1"), ("  ", "Post")])
func exportFolderNameStaysInsideTheExportFolder(name: String, folder: String) {
    #expect(PostExporter.safeFileName(name) == folder)
}

@Test func canvasAtFullResolutionStaysUnderThePixelLimit() {
    // The first photo is 9000 px wide in a box a fifth of a slide wide: at native size a slide would be 45,000 px.
    var canvas = Photo(url: URL(fileURLWithPath: "/a.jpg"))
    canvas.stacked = [Photo(url: URL(fileURLWithPath: "/b.jpg"))]
    canvas.slideCount = 3
    canvas.boxes = [CanvasBox(x: 0, y: 0, width: 0.2, height: 0.2), CanvasBox(x: 1, y: 0, width: 1, height: 1)]
    var frame = FrameSettings()
    frame.ratio = .portrait4x5

    let sizes = [CGSize(width: 9000, height: 6000), CGSize(width: 6000, height: 4000)]
    let width = PostExporter.canvasWidth(for: canvas, croppedSizes: sizes, frame: frame, size: .fullResolution, hasCaption: false)

    #expect(width * 3 * width / 0.8 <= PostExporter.maxFreeCanvasPixels)
    #expect(width > 5000)
}

@Test func boxFromADamagedLibraryIsCutDownToASizeThatCanBeDrawn() {
    let box = CanvasBox(x: 0, y: 0, width: 1e16, height: 1e16).kept(onSlides: 2)

    #expect(box.width == CanvasBox.maximumWidth)
    #expect(box.height == CanvasBox.maximumHeight)
}
