import CoreGraphics
import Foundation
import Testing

@testable import AutopostCore

private func photo(_ name: String) -> Photo {
    Photo(url: URL(fileURLWithPath: "/Pictures/\(name).jpg"))
}

/// A canvas of four photos, a.jpg to d.jpg, in a grid, which keeps them in that drawing order.
private func canvas() -> Photo {
    Photo.canvas(of: [photo("a"), photo("b"), photo("c"), photo("d")], template: .grid, slideRatio: 0.8, seed: 7)!
}

@Test(arguments: CanvasTemplate.allCases, [1, 2, 3, 5, 12])
func templatePlacesEveryPhotoInsideItsSlides(template: CanvasTemplate, count: Int) {
    for seed in UInt64(0)..<25 {
        let arrangement = template.arrangement(photoCount: count, slideRatio: 0.8, seed: seed)

        #expect(arrangement.boxes.count == count)
        #expect(arrangement.isBackground.count == count)
        #expect((1...Photo.maxCanvasSlides).contains(arrangement.slideCount))
        for box in arrangement.boxes {
            #expect(box.x >= -0.000_001 && box.maxX <= Double(arrangement.slideCount) + 0.000_001)
            #expect(box.y >= 0 && box.maxY <= 1.000_001)
            #expect(box.width >= CanvasBox.minimumSide)
        }
    }
}

@Test func templateForManyPhotosIsSqueezedOntoTwentySlides() {
    let arrangement = CanvasTemplate.overlayWide.arrangement(photoCount: 30, slideRatio: 0.8, seed: 7)

    #expect(arrangement.slideCount == 20)
    #expect(arrangement.boxes.map(\.maxX).max()! <= 20)
}

@Test func canvasTakesStacksApartAndKeepsEveryPhoto() {
    var stack = photo("a")
    stack.stacked = [photo("b")]
    let canvas = Photo.canvas(of: [stack, photo("c")], template: .grid, slideRatio: 0.8, seed: 7)!

    #expect(canvas.isCanvas && !canvas.isStack)
    #expect(canvas.images.map(\.url.lastPathComponent) == ["a.jpg", "b.jpg", "c.jpg"])
    #expect(canvas.boxes.count == 3)
}

@Test func overlayBackgroundsFillEverySlideWithNoGaps() {
    for seed in UInt64(0)..<25 {
        let arrangement = CanvasTemplate.overlay.arrangement(photoCount: 7, slideRatio: 0.8, seed: seed)
        let backgrounds = zip(arrangement.boxes, arrangement.isBackground).filter(\.1).map(\.0)

        #expect(backgrounds.first?.x == 0)
        #expect(backgrounds.last?.maxX == Double(arrangement.slideCount))
        for (left, right) in zip(backgrounds, backgrounds.dropFirst()) {
            #expect(abs(left.maxX - right.x) < 0.000_001)
        }
        #expect(backgrounds.allSatisfy { $0.y == 0 && $0.height == 1 })
    }
}

@Test func overlayPhotosOnTopNeverTouchEachOther() {
    for seed in UInt64(0)..<25 {
        let arrangement = CanvasTemplate.overlaySplit.arrangement(photoCount: 9, slideRatio: 0.8, seed: seed)
        let insets = zip(arrangement.boxes, arrangement.isBackground).filter { !$0.1 }.map(\.0).sorted { $0.x < $1.x }

        for (left, right) in zip(insets, insets.dropFirst()) {
            #expect(left.maxX < right.x)
        }
    }
}

@Test func someOverlayBackgroundsRunAcrossTwoSlides() {
    let widths = (UInt64(0)..<25).flatMap { seed in
        let arrangement = CanvasTemplate.overlay.arrangement(photoCount: 8, slideRatio: 0.8, seed: seed)
        return zip(arrangement.boxes, arrangement.isBackground).filter(\.1).map(\.0.width)
    }

    #expect(widths.contains { $0 >= 2 })
    #expect(widths.contains { $0 == 1 })
}

@Test func sameSeedGivesTheSameArrangementAndANewSeedAnother() {
    let first = CanvasTemplate.overlay.arrangement(photoCount: 8, slideRatio: 0.8, seed: 3)

    #expect(first == CanvasTemplate.overlay.arrangement(photoCount: 8, slideRatio: 0.8, seed: 3))
    #expect(first != CanvasTemplate.overlay.arrangement(photoCount: 8, slideRatio: 0.8, seed: 4))
}

@Test func arrangingDrawsBackgroundsFirstAndKeepsThePhotosLeftToRight() {
    let photos = ["a", "b", "c", "d", "e", "f"].map(photo)
    for seed in UInt64(0)..<25 {
        var canvas = Photo.canvas(of: photos, template: .overlay, slideRatio: 0.8, seed: seed)!
        let backgroundCount = canvas.boxes.filter { $0.height == 1 }.count

        // The backgrounds are drawn first, under the photos on top.
        #expect(canvas.boxes.prefix(backgroundCount).allSatisfy { $0.height == 1 })

        canvas.arrange(.grid, slideRatio: 0.8, seed: seed)
        #expect(canvas.images.map(\.url.lastPathComponent) == ["a.jpg", "b.jpg", "c.jpg", "d.jpg", "e.jpg", "f.jpg"])
    }
}

@Test func borderInsetsThePhotoInsideItsBox() {
    let boxes = [CanvasBox(x: 0.2, y: 0.2, width: 0.6, height: 0.6, border: 0.02)]
    let layout = FrameLayout(canvasBoxes: boxes, slideCount: 1, frame: FrameSettings(), canvasWidth: 1000)

    #expect(layout.matRects == [CGRect(x: 200, y: 250, width: 600, height: 750)])
    #expect(layout.imageRects == [CGRect(x: 220, y: 270, width: 560, height: 710)])
}

@Test func blurIsCarriedToTheLayoutInSlideWidths() {
    var box = CanvasBox(x: 0, y: 0, width: 2, height: 1)
    box.blur = 0.5
    let layout = FrameLayout(canvasBoxes: [box, CanvasBox(x: 0.2, y: 0.2, width: 0.5, height: 0.5)], slideCount: 2, frame: FrameSettings(), canvasWidth: 1000)

    #expect(layout.blurRadii == [20, 0])
}

@Test func boxSavedWithoutABorderLoadsWithNone() throws {
    let box = try JSONDecoder().decode(CanvasBox.self, from: Data(#"{"x": 0.5, "y": 0.1, "width": 1, "height": 0.5}"#.utf8))

    #expect(box == CanvasBox(x: 0.5, y: 0.1, width: 1, height: 0.5))
}

@Test func backgroundFillsEverySlideTheBoxTouches() {
    let box = CanvasBox(x: 0.7, y: 0.3, width: 0.8, height: 0.4, border: 0.02)

    #expect(box.asBackground(onSlides: 3) == CanvasBox(x: 0, y: 0, width: 2, height: 1))
}

@Test func canvasLayoutScalesBoxesToTheSlides() {
    let boxes = [CanvasBox(x: 0.5, y: 0.25, width: 1, height: 0.5)]
    var frame = FrameSettings()
    frame.ratio = .portrait4x5
    let layout = FrameLayout(canvasBoxes: boxes, slideCount: 3, frame: frame, canvasWidth: 1000)

    #expect(layout.canvasSize == CGSize(width: 3000, height: 1250))
    #expect(layout.imageRects == [CGRect(x: 500, y: 312.5, width: 1000, height: 625)])
    #expect(layout.slideCount == 3)
}

@Test func bringingAPhotoToTheFrontKeepsItsBoxAndTheCanvasIdentity() {
    var canvas = canvas()
    let id = canvas.id
    let firstBox = canvas.boxes[0]
    canvas.moveImage(from: 0, to: 3)

    #expect(canvas.id == id)
    #expect(canvas.images.map(\.url.lastPathComponent) == ["b.jpg", "c.jpg", "d.jpg", "a.jpg"])
    #expect(canvas.boxes[3] == firstBox)
}

@Test func removingAPhotoGivesItBackAndLeavesTheRest() {
    var canvas = canvas()
    let removed = canvas.removeImage(at: 0)

    #expect(removed?.url.lastPathComponent == "a.jpg")
    #expect(removed?.isCanvas == false)
    #expect(canvas.images.map(\.url.lastPathComponent) == ["b.jpg", "c.jpg", "d.jpg"])
    #expect(canvas.boxes.count == 3)
}

@Test func lastPhotoOfACanvasCannotBeRemoved() {
    var canvas = Photo.canvas(of: [photo("a")], template: .grid, slideRatio: 0.8, seed: 7)!

    #expect(canvas.removeImage(at: 0) == nil)
    #expect(canvas.images.count == 1)
}

@Test func breakingACanvasApartGivesPlainPhotos() {
    let photos = canvas().brokenApart

    #expect(photos.map(\.url.lastPathComponent) == ["a.jpg", "b.jpg", "c.jpg", "d.jpg"])
    #expect(photos.allSatisfy { !$0.isCanvas && !$0.isStack && $0.slideCount == 1 })
}

@Test func newTextOnACanvasLandsOnTheSelectedPhotoInALightColour() {
    var canvas = canvas()
    canvas.slideCount = 4
    canvas.boxes[1] = CanvasBox(x: 2, y: 0, width: 1, height: 1)
    let box = canvas.placingOnCanvas(TextBox(), overImage: 1)

    // The middle of the third of four slides.
    #expect(box.x == 0.625 && box.y == 0.5)
    #expect(box.color.isLight)
}

@Test func newTextOnACanvasWithNothingSelectedLandsOnTheFirstSlide() {
    var canvas = canvas()
    canvas.slideCount = 4
    canvas.boxes = canvas.boxes.map { _ in CanvasBox(x: 3, y: 0.8, width: 0.5, height: 0.1) }
    let box = canvas.placingOnCanvas(TextBox(), overImage: nil)

    #expect(box.x == 0.125 && box.y == 0.5)
    // No photo is under it there, so it keeps its dark colour for the plain background.
    #expect(!box.color.isLight)
}

@Test func gridIsLaidOutAgainWhenASlideIsAdded() {
    var canvas = canvas()
    #expect(canvas.slideCount == 1 && canvas.gridSpacing == CanvasGrid.defaultSpacing)

    canvas.slideCount = 2
    canvas.regrid(slideRatio: 0.8)

    // Two photos on each slide now, above each other on a portrait slide.
    #expect(canvas.boxes.map { Int($0.x) } == [0, 0, 1, 1])
    #expect(canvas.boxes[0].x == canvas.boxes[1].x && canvas.boxes[0].y < canvas.boxes[1].y)
}

@Test func gridSpacingOfZeroMakesThePhotosTouch() {
    let boxes = CanvasGrid.boxes(photoCount: 4, slideCount: 1, slideRatio: 0.8, spacing: 0)

    #expect(boxes == [
        CanvasBox(x: 0, y: 0, width: 0.5, height: 0.5), CanvasBox(x: 0.5, y: 0, width: 0.5, height: 0.5),
        CanvasBox(x: 0, y: 0.5, width: 0.5, height: 0.5), CanvasBox(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
    ])
}

@Test func swappingTwoPhotosExchangesThemAndLeavesTheBoxes() {
    var canvas = canvas()
    let boxes = canvas.boxes
    canvas.swapImages(0, 3)

    #expect(canvas.images.map(\.url.lastPathComponent) == ["d.jpg", "b.jpg", "c.jpg", "a.jpg"])
    #expect(canvas.boxes == boxes)
}

@Test func swappingTwoPhotosOfAStackKeepsEachPhotosCrop() {
    var stack = Photo(url: URL(fileURLWithPath: "/a.jpg"))
    stack.stacked = [Photo(url: URL(fileURLWithPath: "/b.jpg")), Photo(url: URL(fileURLWithPath: "/c.jpg"))]
    stack.crop = CropRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
    let id = stack.id
    stack.swapImages(0, 2)

    #expect(stack.images.map(\.url.lastPathComponent) == ["c.jpg", "b.jpg", "a.jpg"])
    #expect(stack.images[2].crop == CropRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5))
    #expect(stack.images[0].crop == .full)
    #expect(stack.id == id && stack.isStack)
}

@Test func takingAPhotoOutOfAStackOfTwoLeavesASinglePhoto() {
    var stack = Photo(url: URL(fileURLWithPath: "/a.jpg"))
    stack.stacked = [Photo(url: URL(fileURLWithPath: "/b.jpg"))]
    let id = stack.id
    let removed = stack.removeImage(at: 0)

    #expect(removed?.url.lastPathComponent == "a.jpg")
    #expect(stack.url.lastPathComponent == "b.jpg")
    #expect(stack.id == id && !stack.isStack)
    #expect(stack.removeImage(at: 0) == nil)
}

@Test func arrangingAsAnOverlayEndsTheGrid() {
    var canvas = canvas()
    canvas.arrange(.overlay, slideRatio: 0.8, seed: 1)
    let boxes = canvas.boxes
    canvas.regrid(slideRatio: 0.8)

    #expect(canvas.gridSpacing == nil)
    #expect(canvas.boxes == boxes)
}

@Test func canvasSurvivesSavingAndLoading() throws {
    let canvas = canvas()
    let loaded = try JSONDecoder().decode(Photo.self, from: JSONEncoder().encode(canvas))

    #expect(loaded == canvas)
}

@Test func boxesThatDoNotMatchThePhotosAreReadAsAStack() throws {
    var canvas = canvas()
    canvas.boxes.removeLast()
    let loaded = try JSONDecoder().decode(Photo.self, from: JSONEncoder().encode(canvas))

    #expect(!loaded.isCanvas)
    #expect(loaded.images.count == Photo.maxStackSize)
}

@Test func movedBoxSnapsItsEdgeToASeam() {
    let lines = CanvasSnapping.lines(slideCount: 2, marginX: 0.05, marginY: 0.05, others: [])
    let box = CanvasBox(x: 0.305, y: 0.33, width: 0.7, height: 0.4)
    let result = CanvasSnapping.moved(box, lines: lines, thresholdX: 0.01, thresholdY: 0.01)

    #expect(abs(result.box.maxX - 1) < 0.000_001)
    #expect(result.xGuide == 1)
    #expect(result.yGuide == nil)
}

@Test func movedBoxSnapsToAnotherPhotosEdge() {
    let other = CanvasBox(x: 1.2, y: 0.13, width: 0.5, height: 0.5)
    let lines = CanvasSnapping.lines(slideCount: 2, marginX: 0.05, marginY: 0.05, others: [other])
    let result = CanvasSnapping.moved(CanvasBox(x: 0.2, y: 0.135, width: 0.3, height: 0.2), lines: lines, thresholdX: 0.01, thresholdY: 0.01)

    #expect(result.box.y == 0.13)
}

@Test func resizingMovesOnlyTheHeldEdgeAndStopsAtTheSmallestBox() {
    let box = CanvasBox(x: 0.2, y: 0.2, width: 0.4, height: 0.4)
    let right = CanvasSnapping.Handle(horizontal: 1, vertical: 0)
    let wider = CanvasSnapping.resized(box, handle: right, byX: 0.3, y: 0.5, lines: nil, thresholdX: 0.01, thresholdY: 0.01).box
    let crushed = CanvasSnapping.resized(box, handle: right, byX: -2, y: 0, lines: nil, thresholdX: 0.01, thresholdY: 0.01).box

    #expect(abs(wider.width - 0.7) < 0.000_001)
    #expect(wider.x == 0.2 && wider.y == 0.2 && wider.height == 0.4)
    #expect(abs(crushed.width - CanvasBox.minimumSide) < 0.000_001)
    #expect(crushed.x == 0.2)
}

/// A stack of three whose second and third photos each had a text box of their own before they were stacked.
private func stackWithKeptText() -> Photo {
    var stack = photo("a")
    stack.stacked = [photo("b"), photo("c")]
    for index in stack.stacked.indices {
        var box = TextBox()
        box.text = stack.stacked[index].url.deletingPathExtension().lastPathComponent
        stack.stacked[index].textBoxes = [box]
    }
    return stack
}

@Test func photoTakenOutOfAStackComesBackWithTheTextItHadBefore() {
    var stack = stackWithKeptText()
    let removed = stack.removeImage(at: 1)

    #expect(removed?.url.lastPathComponent == "b.jpg")
    #expect(removed?.textBoxes.map(\.text) == ["b"])
    #expect(stack.stacked.map { $0.textBoxes.map(\.text) } == [["c"]])
}

@Test func swappingPhotosBelowTheFirstMovesTheirKeptTextWithThem() {
    var stack = stackWithKeptText()
    stack.swapImages(1, 2)

    #expect(stack.stacked.map(\.url.lastPathComponent) == ["c.jpg", "b.jpg"])
    #expect(stack.stacked.map { $0.textBoxes.map(\.text) } == [["c"], ["b"]])
}

@Test func swappingWithTheFirstPhotoNeverGivesTwoPhotosTheSameID() {
    var stack = stackWithKeptText()
    stack.swapImages(0, 2)

    #expect(Set(stack.images.map(\.id)).count == 3)
}

@Test func textStaysOverTheSameSpotWhenACanvasGetsMoreSlides() {
    var canvas = canvas()
    canvas.setCanvasSlideCount(2)
    var box = TextBox()
    box.x = 0.25
    canvas.textBoxes = [box]
    canvas.setCanvasSlideCount(4)

    // The middle of the first slide: a quarter of two slides, an eighth of four.
    #expect(canvas.textBoxes[0].x == 0.125)
}

@Test func crowdedGridAtTheWidestSpacingStillGivesEveryPhotoACell() {
    let boxes = CanvasGrid.boxes(photoCount: 16, slideCount: 1, slideRatio: 1.91, spacing: CanvasGrid.spacingRange.upperBound)

    for box in boxes {
        #expect(box.width >= CanvasBox.minimumSide - 0.000_001 && box.height >= CanvasBox.minimumSide - 0.000_001)
        #expect(box.x >= 0 && box.maxX <= 1.000_001 && box.y >= 0 && box.maxY <= 1.000_001)
    }
}
