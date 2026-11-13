import CoreGraphics
import Foundation
import Testing

@testable import AutopostCore

@Test func landscapePhotoInPortraitFrameIsCenteredWithMinimumSideBorder() {
    var frame = FrameSettings()
    frame.borderPercent = 5
    let layout = FrameLayout(imageSize: CGSize(width: 6000, height: 4000), frame: frame, canvasWidth: 1080)

    #expect(layout.canvasSize == CGSize(width: 1080, height: 1350))
    #expect(abs(layout.imageRect.minX - 54) < 0.001)
    #expect(abs(layout.imageRect.width - 972) < 0.001)
    #expect(abs(layout.imageRect.midY - 675) < 0.001)
}

@Test func portraitPhotoIsLimitedByTopAndBottomBorder() {
    var frame = FrameSettings()
    frame.ratio = .square
    frame.borderPercent = 10
    let layout = FrameLayout(imageSize: CGSize(width: 4000, height: 6000), frame: frame, canvasWidth: 1000)

    #expect(abs(layout.imageRect.minY - 100) < 0.001)
    #expect(abs(layout.imageRect.height - 800) < 0.001)
}

@Test func originalRatioKeepsAnEvenBorder() {
    var frame = FrameSettings()
    frame.ratio = .original
    frame.borderPercent = 10
    let layout = FrameLayout(imageSize: CGSize(width: 3000, height: 2000), frame: frame, canvasWidth: 1000)

    #expect(layout.canvasSize == CGSize(width: 1000, height: 733.3333333333334))
    #expect(layout.imageRect == CGRect(x: 100, y: 100, width: 800, height: 533.3333333333334))
}

@Test func negativeOffsetMovesPhotoToTopOfFreeSpace() {
    var frame = FrameSettings()
    frame.verticalOffset = -1
    let layout = FrameLayout(imageSize: CGSize(width: 3000, height: 2000), frame: frame, canvasWidth: 1000)

    #expect(abs(layout.imageRect.minY - 50) < 0.001)
}

@Test func addingACaptionDoesNotMoveThePhotoWhenItFitsUnderIt() {
    let photo = CGSize(width: 3000, height: 2000)
    let plain = FrameLayout(imageSize: photo, frame: FrameSettings(), canvasWidth: 1000)
    let captioned = FrameLayout(imageSize: photo, frame: FrameSettings(), canvasWidth: 1000, hasCaption: true)

    #expect(captioned.imageRect == plain.imageRect)
    #expect(abs(captioned.captionRect!.minY - plain.imageRect.maxY) < 0.001)
}

@Test func captionMovesThePhotoUpOnlyAsFarAsItNeeds() {
    var frame = FrameSettings()
    frame.verticalOffset = 1
    frame.captionSize = 0.1
    let layout = FrameLayout(imageSize: CGSize(width: 3000, height: 2000), frame: frame, canvasWidth: 1000, hasCaption: true)

    // Pushed to the bottom the photo ends at 1150; the 180 band needs it to end at 1070.
    #expect(abs(layout.imageRect.maxY - 1070) < 0.001)
    #expect(abs(layout.imageRect.height - 600) < 0.001)
    #expect(abs(layout.captionRect!.maxY - 1250) < 0.001)
}

@Test func captionShrinksThePhotoOnlyOnceItReachesTheTopBorder() {
    var frame = FrameSettings()
    frame.ratio = .square
    frame.captionSize = 0.05
    let layout = FrameLayout(imageSize: CGSize(width: 2000, height: 3000), frame: frame, canvasWidth: 1000, hasCaption: true)

    #expect(abs(layout.imageRect.minY - 50) < 0.001)
    #expect(abs(layout.imageRect.height - 860) < 0.001)
    #expect(abs(layout.captionRect!.maxY - 1000) < 0.001)
}

@Test func fullResolutionKeepsPhotoAtNativeWidth() {
    let photo = Photo(url: URL(fileURLWithPath: "/photo.jpg"))
    let width = PostExporter.canvasWidth(
        for: photo, croppedSizes: [CGSize(width: 6000, height: 4000)], frame: FrameSettings(), size: .fullResolution, hasCaption: false
    )
    let layout = FrameLayout(imageSize: CGSize(width: 6000, height: 4000), frame: FrameSettings(), canvasWidth: width)

    #expect(abs(layout.imageRect.width - 6000) < 1)
}

@Test(arguments: [(0.004, "1/250s"), (2.5, "2.5s"), (1.0 / 30, "1/30s")])
func shutterSpeedReadsLikeACamera(seconds: Double, label: String) {
    #expect(ImageSource.shutterLabel(seconds) == label)
}

@Test func slugDropsPunctuation() {
    #expect(PostExporter.slug("Cali on film #2") == "cali-on-film-2")
}

@Test func photoNarrowerThanCanvasCanBePushedRight() {
    var frame = FrameSettings()
    frame.ratio = .landscape16x9
    frame.horizontalOffset = 1
    let layout = FrameLayout(imageSize: CGSize(width: 2000, height: 3000), frame: frame, canvasWidth: 1600)

    #expect(abs(layout.imageRect.maxX - 1520) < 0.001)
}

@Test func photoAdjustmentsOverrideOnlyWhatTheySet() {
    var frame = FrameSettings()
    frame.borderPercent = 5
    frame.verticalOffset = 0.5
    var adjustments = PhotoAdjustments()
    adjustments.borderPercent = 12

    let applied = frame.applying(adjustments)

    #expect(applied.borderPercent == 12)
    #expect(applied.verticalOffset == 0.5)
}

@Test func savedRatioIsUsedAsCustomRatio() {
    var frame = FrameSettings()
    let ultrawide = SavedRatio(width: 32, height: 9)
    frame.use(ultrawide)

    #expect(frame.uses(ultrawide))
    #expect(abs(frame.ratioValue! - 32.0 / 9.0) < 0.0001)
}

// * ====================================================================
// * === panoramas and stacks
// * ====================================================================

@Test func panoramaOverTwoSlidesIsOneCanvasTwoSlidesWide() {
    var frame = FrameSettings()
    frame.borderPercent = 5
    let layout = FrameLayout(imageSize: CGSize(width: 8000, height: 4000), frame: frame, canvasWidth: 1080, slideCount: 2)

    #expect(layout.canvasSize == CGSize(width: 2160, height: 1350))
    #expect(abs(layout.imageRect.minX - 54) < 0.001)
    #expect(abs(layout.imageRect.maxX - 2106) < 0.001)
    #expect(layout.slideRect(1) == CGRect(x: 1080, y: 0, width: 1080, height: 1350))
    #expect(abs(layout.slideRatio - 0.8) < 0.000_001)
}

@Test func panoramaHasTheSameBorderOnEverySide() {
    var frame = FrameSettings()
    frame.borderPercent = 5
    // A 3:2 photo over two 4:5 slides is narrower than the canvas, so fitting it would leave wide bands at the ends.
    let layout = FrameLayout(imageSize: CGSize(width: 6000, height: 4000), frame: frame, canvasWidth: 1080, slideCount: 2)

    #expect(layout.imageRect == CGRect(x: 54, y: 54, width: 2052, height: 1242))
}

@Test func panoramaCaptionSitsUnderTheLastSlideOnly() {
    var frame = FrameSettings()
    frame.borderPercent = 5
    let layout = FrameLayout(imageSize: CGSize(width: 8000, height: 4000), frame: frame, canvasWidth: 1000, hasCaption: true, slideCount: 2)

    #expect(layout.captionRect!.minX == 1000)
    #expect(abs(layout.captionRect!.maxX - layout.imageRect.maxX) < 0.001)
}

@Test func stackedPhotosShareAPortraitSlideEquallyWithBorderGaps() {
    var frame = FrameSettings()
    frame.borderPercent = 2
    let sizes = Array(repeating: CGSize(width: 3000, height: 2000), count: 3)
    let layout = FrameLayout(stackedImageSizes: sizes, frame: frame, canvasWidth: 1000)

    #expect(layout.canvasSize == CGSize(width: 1000, height: 1250))
    #expect(layout.imageRects.count == 3)
    // 1250 minus two outer borders and two gaps of 20 px, split three ways.
    let height = (1250.0 - 4 * 20) / 3
    for (index, rect) in layout.imageRects.enumerated() {
        #expect(abs(rect.height - height) < 0.001)
        #expect(abs(rect.minY - (20 + Double(index) * (height + 20))) < 0.001)
        #expect(rect.minX == 20 && rect.width == 960)
    }
    #expect(abs(layout.imageRect.maxY - 1230) < 0.001)
}

@Test func stackWithTheOriginalRatioKeepsEveryPhotosShape() {
    var frame = FrameSettings()
    frame.ratio = .original
    frame.borderPercent = 10
    let layout = FrameLayout(stackedImageSizes: [CGSize(width: 3000, height: 2000), CGSize(width: 2000, height: 2000)], frame: frame, canvasWidth: 1000)

    #expect(layout.imageRects[0] == CGRect(x: 100, y: 100, width: 800, height: 533.3333333333334))
    #expect(layout.imageRects[1] == CGRect(x: 100, y: 733.3333333333334, width: 800, height: 800))
    #expect(abs(layout.canvasSize.height - 1633.3333333333335) < 0.001)
}

@Test func stackMakesRoomForTheCaptionUnderTheLastPhoto() {
    var frame = FrameSettings()
    frame.borderPercent = 2
    let sizes = Array(repeating: CGSize(width: 3000, height: 2000), count: 2)
    let layout = FrameLayout(stackedImageSizes: sizes, frame: frame, canvasWidth: 1000, hasCaption: true)

    let band = frame.captionSize * FrameLayout.captionBandPerFontSize * 1000
    #expect(abs(layout.captionRect!.minY - layout.imageRects[1].maxY) < 0.001)
    #expect(abs(layout.captionRect!.maxY - (1250 - 20)) < 0.001)
    #expect(abs(layout.captionRect!.height - band) < 0.001)
}
