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
    try PostExporter.exportPhoto(photo, to: target, frame: frame, settings: ExportSettings(), cameraNames: [:])

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

@Test(arguments: [("..", "Post"), (".hidden", "hidden"), ("Trip/1", "Trip-1"), ("  ", "Post")])
func exportFolderNameStaysInsideTheExportFolder(name: String, folder: String) {
    #expect(PostExporter.safeFileName(name) == folder)
}
