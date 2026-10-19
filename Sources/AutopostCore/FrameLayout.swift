import CoreGraphics

/// Where the photo and caption sit on the canvas. Rects use a top-left origin.
///
/// The preview and the exporter both use this, so what the grid shows is exactly what gets written.
public struct FrameLayout: Equatable, Sendable {
    // The band kept under the photo for the caption is this many times the caption's font size.
    public static let captionBandPerFontSize = 3.0
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
        let innerHeight = max(canvasHeight - 2 * border - captionBand, 1)
        let scale = min(innerWidth / imageSize.width, innerHeight / imageSize.height)
        let photoSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        let freeWidth = innerWidth - photoSize.width
        let freeHeight = innerHeight - photoSize.height
        let x = border + freeWidth / 2 * (1 + Self.clamped(frame.horizontalOffset))
        let y = border + freeHeight / 2 * (1 + Self.clamped(frame.verticalOffset))

        canvasSize = CGSize(width: canvasWidth, height: canvasHeight)
        imageRect = CGRect(origin: CGPoint(x: x, y: y), size: photoSize)
        captionRect = hasCaption ? Self.captionRect(below: imageRect, height: captionBand) : nil
    }

    private static func clamped(_ offset: Double) -> Double {
        min(max(offset, -1), 1)
    }

    private static func captionRect(below image: CGRect, height: Double) -> CGRect {
        CGRect(x: image.minX, y: image.maxY, width: image.width, height: height)
    }
}
