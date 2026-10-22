import CoreGraphics

/// Where the photo and caption sit on the canvas. Rects use a top-left origin.
///
/// The preview and the exporter both use this, so what the grid shows is exactly what gets written.
public struct FrameLayout: Equatable, Sendable {
    // The band kept under the photo for the caption is this many times the caption's font size. The text is centred
    // in it, so this keeps the gap above the text small enough that the caption reads as part of the photo.
    public static let captionBandPerFontSize = 1.8
    // A wider border leaves too little room for the photo to be worth showing.
    public static let maxBorderPercent = 30.0

    public var canvasSize: CGSize
    public var imageRect: CGRect
    public var captionRect: CGRect?

    public init(imageSize: CGSize, frame: FrameSettings, canvasWidth: Double, hasCaption: Bool = false) {
        let border = min(max(frame.borderPercent, 0), Self.maxBorderPercent) / 100 * canvasWidth
        let captionBand = hasCaption ? frame.captionSize * Self.captionBandPerFontSize * canvasWidth : 0
        let innerWidth = canvasWidth - 2 * border
        let photoRatio = imageSize.width / max(imageSize.height, 1)

        guard let ratio = frame.ratioValue else {
            let photoHeight = innerWidth / photoRatio
            canvasSize = CGSize(width: canvasWidth, height: photoHeight + 2 * border + captionBand)
            imageRect = CGRect(x: border, y: border, width: innerWidth, height: photoHeight)
            captionRect = hasCaption ? Self.captionRect(below: imageRect, height: captionBand) : nil
            return
        }

        let canvasHeight = canvasWidth / ratio
        let innerHeight = max(canvasHeight - 2 * border, 1)
        let photo = Self.placedPhoto(imageSize, inWidth: innerWidth, height: innerHeight, border: border, frame: frame)

        canvasSize = CGSize(width: canvasWidth, height: canvasHeight)
        imageRect = hasCaption ? Self.makingRoom(captionBand, below: photo, imageSize: imageSize, canvasHeight: canvasHeight,
                                                 innerWidth: innerWidth, border: border, frame: frame) : photo
        captionRect = hasCaption ? Self.captionRect(below: imageRect, height: captionBand) : nil
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

    private static func captionRect(below image: CGRect, height: Double) -> CGRect {
        CGRect(x: image.minX, y: image.maxY, width: image.width, height: height)
    }
}
