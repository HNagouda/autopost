import CoreGraphics
import CoreText
import Testing

@testable import AutopostCore

@Test func centeredBoxIsCenteredOnItsAnchor() {
    var box = TextBox()
    box.x = 0.5
    box.y = 0.5
    let bounds = TextBoxRenderer.bounds(for: box, canvasSize: CGSize(width: 1080, height: 1350))

    #expect(abs(bounds.midX - 540) < 0.5)
    #expect(abs(bounds.midY - 675) < 0.5)
}

@Test func leadingBoxStartsAtItsAnchor() {
    var box = TextBox()
    box.alignment = .leading
    box.x = 0.1
    let bounds = TextBoxRenderer.bounds(for: box, canvasSize: CGSize(width: 1000, height: 1250))

    #expect(abs(bounds.minX - 100) < 0.5)
}

@Test func boxScalesWithTheCanvas() {
    var box = TextBox()
    box.text = "Monterey\nKodak Gold 200"
    let small = TextBoxRenderer.bounds(for: box, canvasSize: CGSize(width: 1080, height: 1350))
    let large = TextBoxRenderer.bounds(for: box, canvasSize: CGSize(width: 4320, height: 5400))

    #expect(abs(large.width / small.width - 4) < 0.05)
    #expect(abs(large.height / small.height - 4) < 0.05)
}

@Test func italicFallsBackToSlantForFamiliesWithoutItalic() {
    var box = TextBox()
    box.fontFamily = "Futura"
    box.isItalic = true
    let font = TextBoxRenderer.font(for: box, canvasWidth: 1000)

    #expect(CTFontGetSize(font) == 35)
}

@Test func boxNearTheBottomBorderMiddleSnapsToIt() {
    var frame = FrameSettings()
    frame.ratio = .square
    let layout = FrameLayout(imageSize: CGSize(width: 3000, height: 2000), frame: frame, canvasWidth: 1000)
    let bottomBorderMiddle = (layout.imageRect.maxY + 1000) / 2 / 1000

    let result = TextSnapping.snap(CGPoint(x: 0.43, y: bottomBorderMiddle + 0.01), layout: layout)

    #expect(abs(result.point.y - bottomBorderMiddle) < 0.0001)
    #expect(result.xGuide == nil)
}

@Test func boxFarFromEveryLineStaysPut() {
    let layout = FrameLayout(imageSize: CGSize(width: 3000, height: 2000), frame: FrameSettings(), canvasWidth: 1000)

    let result = TextSnapping.snap(CGPoint(x: 0.46, y: 0.205), layout: layout)

    #expect(result.point == CGPoint(x: 0.46, y: 0.205))
}
