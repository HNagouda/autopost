import CoreGraphics

/// Where the photos and caption sit on the canvas. Rects use a top-left origin.
///
/// The preview and the exporter both use this, so what the grid shows is exactly what gets written. A panorama is
/// laid out as one canvas several slides wide and cut into slides afterwards, which is what makes the seam between
/// two slides line up exactly. A stack puts two or three photos above each other on one slide.
public struct FrameLayout: Equatable, Sendable {
    // The band kept under the photo for the caption is this many times the caption's font size. The text is centred
    // in it, so this keeps the gap above the text small enough that the caption reads as part of the photo.
    public static let captionBandPerFontSize = 1.8
    // A wider border leaves too little room for the photo to be worth showing.
    public static let maxBorderPercent = 30.0

    public var canvasSize: CGSize
    // Around every photo on the canvas; for a stack, from the top of the first photo to the bottom of the last.
    public var imageRect: CGRect
    // One rect per photo, top to bottom. A stacked photo is cropped to fill its rect.
    public var imageRects: [CGRect]
    public var captionRect: CGRect?
    // How many slides the canvas is cut into, side by side.
    public var slideCount = 1

    /// One photo on one slide, or spread over `slideCount` slides. `canvasWidth` is the width of one slide.
    public init(imageSize: CGSize, frame: FrameSettings, canvasWidth: Double, hasCaption: Bool = false, slideCount: Int = 1) {
        let border = Self.border(frame, slideWidth: canvasWidth)
        let captionBand = hasCaption ? frame.captionSize * Self.captionBandPerFontSize * canvasWidth : 0
        let fullWidth = canvasWidth * Double(slideCount)
        let innerWidth = fullWidth - 2 * border
        let photoRatio = imageSize.width / max(imageSize.height, 1)
        self.slideCount = slideCount

        guard let ratio = frame.ratioValue else {
            let photoHeight = innerWidth / photoRatio
            canvasSize = CGSize(width: fullWidth, height: photoHeight + 2 * border + captionBand)
            imageRect = CGRect(x: border, y: border, width: innerWidth, height: photoHeight)
            imageRects = [imageRect]
            captionRect = hasCaption ? Self.captionRect(below: imageRect, height: captionBand, lastSlideStart: fullWidth - canvasWidth) : nil
            return
        }

        let canvasHeight = canvasWidth / ratio
        let innerHeight = max(canvasHeight - 2 * border, 1)
        canvasSize = CGSize(width: fullWidth, height: canvasHeight)

        // A panorama fills the space inside the border and is cropped to it, so the border is equally wide on every
        // side. Fitted instead, a photo whose shape differs from the slides would leave wide bands at the ends.
        if slideCount > 1 {
            imageRect = CGRect(x: border, y: border, width: innerWidth, height: max(innerHeight - captionBand, 1))
            imageRects = [imageRect]
            captionRect = hasCaption ? Self.captionRect(below: imageRect, height: captionBand, lastSlideStart: fullWidth - canvasWidth) : nil
            return
        }

        let photo = Self.placedPhoto(imageSize, inWidth: innerWidth, height: innerHeight, border: border, frame: frame)
        imageRect = hasCaption ? Self.makingRoom(captionBand, below: photo, imageSize: imageSize, canvasHeight: canvasHeight,
                                                 innerWidth: innerWidth, border: border, frame: frame) : photo
        imageRects = [imageRect]
        captionRect = hasCaption ? Self.captionRect(below: imageRect, height: captionBand, lastSlideStart: fullWidth - canvasWidth) : nil
    }

    /// Photos stacked top to bottom on one slide, as far apart as the border is wide.
    ///
    /// With a fixed ratio every photo gets the same height and is cropped to fill it, the way a stack of landscape
    /// photos fills a portrait slide. With the original ratio each photo keeps its shape and the canvas grows to fit.
    public init(stackedImageSizes sizes: [CGSize], frame: FrameSettings, canvasWidth: Double, hasCaption: Bool = false) {
        let border = Self.border(frame, slideWidth: canvasWidth)
        let captionBand = hasCaption ? frame.captionSize * Self.captionBandPerFontSize * canvasWidth : 0
        let innerWidth = canvasWidth - 2 * border
        let gaps = border * Double(max(sizes.count - 1, 0))

        let heights: [Double]
        if let ratio = frame.ratioValue {
            let free = canvasWidth / ratio - 2 * border - gaps - captionBand
            heights = Array(repeating: max(free / Double(max(sizes.count, 1)), 1), count: sizes.count)
        } else {
            heights = sizes.map { innerWidth * $0.height / max($0.width, 1) }
        }

        var rects: [CGRect] = []
        var top = border
        for height in heights {
            rects.append(CGRect(x: border, y: top, width: innerWidth, height: height))
            top += height + border
        }

        let stackRect = rects.dropFirst().reduce(rects.first ?? .zero) { $0.union($1) }
        let canvasHeight = frame.ratioValue.map { canvasWidth / $0 } ?? stackRect.maxY + border + captionBand
        canvasSize = CGSize(width: canvasWidth, height: canvasHeight)
        imageRect = stackRect
        imageRects = rects
        captionRect = hasCaption ? Self.captionRect(below: stackRect, height: captionBand, lastSlideStart: 0) : nil
    }

    /// The layout for a photo on its own, spread over slides, or stacked. `imageSizes` are the cropped sizes of
    /// `photo.images`, in the same order.
    public init(photo: Photo, imageSizes: [CGSize], frame: FrameSettings, canvasWidth: Double, hasCaption: Bool = false) {
        if photo.isStack {
            self.init(stackedImageSizes: imageSizes, frame: frame, canvasWidth: canvasWidth, hasCaption: hasCaption)
        } else {
            self.init(imageSize: imageSizes.first ?? CGSize(width: 3, height: 2), frame: frame, canvasWidth: canvasWidth,
                      hasCaption: hasCaption, slideCount: photo.slideCount)
        }
    }

    /// Width over height of one slide.
    public var slideRatio: Double {
        canvasSize.width / Double(slideCount) / max(canvasSize.height, 1)
    }

    /// Where slide `index`, counted from 0, sits on the canvas.
    public func slideRect(_ index: Int) -> CGRect {
        let width = canvasSize.width / Double(slideCount)
        return CGRect(x: width * Double(index), y: 0, width: width, height: canvasSize.height)
    }

    private static func border(_ frame: FrameSettings, slideWidth: Double) -> Double {
        min(max(frame.borderPercent, 0), maxBorderPercent) / 100 * slideWidth
    }

    /// The photo fitted inside the border and placed by the position sliders.
    private static func placedPhoto(_ imageSize: CGSize, inWidth width: Double, height: Double, border: Double, frame: FrameSettings) -> CGRect {
        let scale = min(width / imageSize.width, height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let x = border + (width - size.width) / 2 * (1 + clamped(frame.horizontalOffset))
        let y = border + (height - size.height) / 2 * (1 + clamped(frame.verticalOffset))
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    /// The photo moved up, then shrunk, only as far as the caption band below it needs.
    private static func makingRoom(
        _ band: Double, below photo: CGRect, imageSize: CGSize, canvasHeight: Double, innerWidth: Double, border: Double, frame: FrameSettings
    ) -> CGRect {
        // Adding a caption should not move the photo, so the band goes in the space under it, border included. Only
        // when that is too small does the photo move up, and only at the top border does it shrink. Each step starts
        // where the last one stops, so dragging the border slider never makes the photo jump.
        let shortfall = photo.maxY + band - canvasHeight
        guard shortfall > 0 else { return photo }
        if photo.minY - shortfall >= border { return photo.offsetBy(dx: 0, dy: -shortfall) }

        let shrunk = placedPhoto(imageSize, inWidth: innerWidth, height: max(canvasHeight - border - band, 1), border: border, frame: frame)
        return CGRect(origin: CGPoint(x: shrunk.minX, y: border), size: shrunk.size)
    }

    private static func clamped(_ offset: Double) -> Double {
        min(max(offset, -1), 1)
    }

    /// Under the photo. On a panorama only under the part in the last slide, so the caption is never cut by a seam.
    private static func captionRect(below image: CGRect, height: Double, lastSlideStart: Double) -> CGRect {
        let minX = max(image.minX, lastSlideStart)
        return CGRect(x: minX, y: image.maxY, width: max(image.maxX - minX, 0), height: height)
    }
}
