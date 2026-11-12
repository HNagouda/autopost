import CoreGraphics
import Testing

@testable import AutopostCore

/// A 300 × 200 photo: a dark picture inside a white margin `border` pixels wide on every side.
private func scan(border: Int) -> CGImage {
    let context = CGContext(
        data: nil, width: 300, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 300, height: 200))
    context.setFillColor(CGColor(red: 0.2, green: 0.3, blue: 0.25, alpha: 1))
    context.fill(CGRect(x: border, y: border, width: 300 - 2 * border, height: 200 - 2 * border))
    return context.makeImage()!
}

@Test func whiteMarginBakedIntoAScanIsCroppedOff() {
    let crop = EdgeTrim.crop(removingBorderOf: scan(border: 10))!

    #expect(abs(crop.x - 10.0 / 300) < 0.005)
    #expect(abs(crop.y - 10.0 / 200) < 0.005)
    #expect(abs(crop.width - 280.0 / 300) < 0.01)
    #expect(abs(crop.height - 180.0 / 200) < 0.01)
}

@Test func photoWithoutAMarginIsLeftAlone() {
    #expect(EdgeTrim.crop(removingBorderOf: scan(border: 0)) == nil)
}
