import CoreGraphics
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

@Test func captionReservesBandUnderPhoto() {
    var frame = FrameSettings()
    frame.ratio = .square
    let layout = FrameLayout(imageSize: CGSize(width: 2000, height: 3000), frame: frame, canvasWidth: 1000, hasCaption: true)

    #expect(abs(layout.captionRect!.maxY - 950) < 0.001)
}

@Test func fullResolutionKeepsPhotoAtNativeWidth() {
    let width = PostExporter.canvasWidth(for: CGSize(width: 6000, height: 4000), frame: FrameSettings(), size: .fullResolution, hasCaption: false)
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
