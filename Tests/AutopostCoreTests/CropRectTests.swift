import CoreGraphics
import Foundation
import Testing

@testable import AutopostCore

private func isClose(_ a: Double, _ b: Double) -> Bool {
    abs(a - b) < 0.0001
}

@Test func freeCornerDragMovesOnlyThatCorner() {
    let crop = CropRect.full.resized(.topLeft, to: CGPoint(x: 0.2, y: 0.1), shape: nil, imageAspect: 1.5)

    #expect(crop == CropRect(x: 0.2, y: 0.1, width: 0.8, height: 0.9))
}

@Test func freeDragStopsAtThePhotoEdgeAndTheMinimumSize() {
    let outside = CropRect.full.resized(.right, to: CGPoint(x: 1.4, y: 0.5), shape: nil, imageAspect: 1.5)
    let crossed = CropRect.full.resized(.left, to: CGPoint(x: 1.2, y: 0.5), shape: nil, imageAspect: 1.5)

    #expect(outside == .full)
    #expect(isClose(crossed.width, CropRect.minimumSide))
}

@Test func lockedCornerDragKeepsTheShapeInPixels() {
    // A 3:2 photo cropped to a square: fractions differ, pixels match.
    let start = CropRect.full.fitted(toShape: 1, imageAspect: 1.5)
    let crop = start.resized(.bottomRight, to: CGPoint(x: 0.6, y: 0.9), shape: 1, imageAspect: 1.5)
    let pixels = crop.size(of: CGSize(width: 3000, height: 2000))

    #expect(isClose(pixels.width, pixels.height))
    #expect(isClose(crop.x, start.x))
    #expect(isClose(crop.y, start.y))
}

@Test func lockedCornerDragShrinksToFitThePhoto() {
    let crop = CropRect(x: 0.5, y: 0.5, width: 0.2, height: 0.2)
        .resized(.bottomRight, to: CGPoint(x: 2, y: 2), shape: 1, imageAspect: 1)

    #expect(isClose(crop.x + crop.width, 1))
    #expect(isClose(crop.width, crop.height))
}

@Test func lockedEdgeDragGrowsEvenlyAboutTheMiddle() {
    let start = CropRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
    let crop = start.resized(.right, to: CGPoint(x: 0.8, y: 0.5), shape: 1, imageAspect: 1)

    #expect(isClose(crop.width, 0.4))
    #expect(isClose(crop.y + crop.height / 2, 0.5))
}

@Test func fittingAShapeTakesTheLargestCropCentredOnTheOldOne() {
    let crop = CropRect.full.fitted(toShape: 4.0 / 5.0, imageAspect: 1.5)
    let pixels = crop.size(of: CGSize(width: 3000, height: 2000))

    #expect(isClose(crop.height, 1))
    #expect(isClose(pixels.width / pixels.height, 0.8))
    #expect(isClose(crop.x + crop.width / 2, 0.5))
}

@Test func movingStopsAtThePhotoEdge() {
    let crop = CropRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5).moved(byX: 0.9, y: -0.3)

    #expect(crop == CropRect(x: 0.5, y: 0, width: 0.5, height: 0.5))
}

@Test func croppedPhotoLaysOutWithTheCropShapeInsideThePostRatio() {
    let crop = CropRect.full.fitted(toShape: 1, imageAspect: 1.5)
    let layout = FrameLayout(imageSize: crop.size(of: CGSize(width: 3000, height: 2000)), frame: FrameSettings(), canvasWidth: 1080)

    // The post stays 4:5; the square photo inside it gets the extra border above and below.
    #expect(layout.canvasSize == CGSize(width: 1080, height: 1350))
    #expect(isClose(layout.imageRect.width, layout.imageRect.height))
}

@Test func renamedCameraAndTypedSettingsReplaceTheExif() {
    let exif = CameraSettings(camera: "ILCE-6400", focalLength: "35mm", aperture: "ƒ/2", shutter: "1/250s", iso: "ISO 100")
    var photo = Photo(url: URL(fileURLWithPath: "/tmp/a.jpg"))
    photo.cameraOverrides.iso = "ISO 400"
    photo.cameraOverrides.shutter = "  "

    let settings = photo.cameraSettings(exif: exif, cameraNames: ["ILCE-6400": "Sony a6400"])

    #expect(settings.line == "Sony a6400  ·  35mm  ·  ƒ/2  ·  1/250s  ·  ISO 400")
}

@Test func filmScanWithoutExifPrintsOnlyWhatWasTyped() {
    var photo = Photo(url: URL(fileURLWithPath: "/tmp/scan.tif"))
    photo.cameraOverrides = CameraSettings(camera: "Pentax K1000", aperture: "ƒ/8", iso: "Portra 400")

    let settings = photo.cameraSettings(exif: CameraSettings(), cameraNames: [:])

    #expect(settings.line == "Pentax K1000  ·  ƒ/8  ·  Portra 400")
    #expect(Photo(url: photo.url).cameraSettings(exif: CameraSettings(), cameraNames: [:]).line == nil)
}

@Test(arguments: [CropHandle.left, .right, .top, .bottom, .topLeft, .bottomRight])
func draggingPastTheOppositeSideStopsAtTheSmallestCrop(handle: CropHandle) {
    let start = CropRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
    // Far past the side opposite the handle.
    let past = CGPoint(x: 1 - handle.anchor.x, y: 1 - handle.anchor.y)

    for shape in [nil, 1.0] {
        let crop = start.resized(handle, to: past, shape: shape, imageAspect: 1)
        #expect(crop.isValid)
        #expect(crop.width <= start.width + 0.0001)
        #expect(crop.height <= start.height + 0.0001)
    }
}
