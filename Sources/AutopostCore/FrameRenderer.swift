import CoreGraphics
import CoreImage
import CoreText
import Foundation

/// Draws a photo onto its framed canvas in sRGB, which is what Instagram expects.
public enum FrameRenderer {
    // Relative to the canvas width, so the frame looks the same at 1080 px and at full resolution.
    public static let blurRadiusFraction = 0.06
    public static let shadowBlurFraction = 0.02
    public static let shadowOffsetFraction = 0.004
    public static let shadowOpacity = 0.28
    // Light output sharpening, roughly Lightroom's "Screen, Low", to offset the softening from downscaling.
    static let sharpness = 0.35

    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let ciContext = CIContext(options: [.workingColorSpace: colorSpace, .outputColorSpace: colorSpace])

    public static func render(image: CGImage, layout: FrameLayout, frame: FrameSettings, caption: String?, isSharpening: Bool) -> CGImage? {
        let width = Int(layout.canvasSize.width.rounded())
        let height = Int(layout.canvasSize.height.rounded())
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        context.interpolationQuality = .high
        drawBackground(in: context, canvas: canvas, image: image, frame: frame)

        let photo = isSharpening ? sharpened(image) ?? image : image
        context.saveGState()
        if frame.hasShadow {
            context.setShadow(
                offset: CGSize(width: 0, height: -shadowOffsetFraction * canvas.width),
                blur: shadowBlurFraction * canvas.width,
                color: CGColor(gray: 0, alpha: shadowOpacity)
            )
        }
        context.draw(photo, in: flipped(layout.imageRect, canvasHeight: canvas.height))
        context.restoreGState()

        if let caption, let captionRect = layout.captionRect {
            drawCaption(caption, in: context, rect: flipped(captionRect, canvasHeight: canvas.height), frame: frame, canvasWidth: canvas.width)
        }

        return context.makeImage()
    }

    // FrameLayout uses a top-left origin; Core Graphics draws from the bottom left.
    private static func flipped(_ rect: CGRect, canvasHeight: Double) -> CGRect {
        CGRect(x: rect.minX, y: canvasHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    private static func drawBackground(in context: CGContext, canvas: CGRect, image: CGImage, frame: FrameSettings) {
        context.setFillColor(CGColor(srgbRed: frame.color.red, green: frame.color.green, blue: frame.color.blue, alpha: 1))
        context.fill(canvas)

        guard frame.background == .blur, let blurred = blurredFill(image, canvas: canvas) else { return }
        context.draw(blurred, in: canvas)
    }

    /// The photo scaled to cover the whole canvas and blurred, like the soft backdrop in story apps.
    private static func blurredFill(_ image: CGImage, canvas: CGRect) -> CGImage? {
        let source = CIImage(cgImage: image)
        let scale = max(canvas.width / source.extent.width, canvas.height / source.extent.height)
        let scaled = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let centered = scaled.transformed(by: CGAffineTransform(
            translationX: (canvas.width - scaled.extent.width) / 2 - scaled.extent.minX,
            y: (canvas.height - scaled.extent.height) / 2 - scaled.extent.minY
        ))
        let blurred = centered
            .clampedToExtent()
            .applyingGaussianBlur(sigma: blurRadiusFraction * canvas.width)
            .cropped(to: canvas)
        return ciContext.createCGImage(blurred, from: canvas)
    }

    private static func sharpened(_ image: CGImage) -> CGImage? {
        let source = CIImage(cgImage: image)
        let output = source.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: sharpness])
        return ciContext.createCGImage(output, from: source.extent)
    }

    private static func drawCaption(_ text: String, in context: CGContext, rect: CGRect, frame: FrameSettings, canvasWidth: Double) {
        let font = CTFontCreateUIFontForLanguage(.system, FrameLayout.captionFontFraction * canvasWidth, nil)!
        let isDarkText = frame.background == .color && frame.color.isLight
        let color = isDarkText ? CGColor(gray: 0.32, alpha: 1) : CGColor(gray: 0.92, alpha: 1)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            NSAttributedString.Key(kCTKernAttributeName as String): 0.04 * CTFontGetSize(font),
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

        // Centered across the photo and vertically in the band under it.
        let x = rect.midX - bounds.width / 2 - bounds.minX
        let y = rect.midY - bounds.height / 2 - bounds.minY
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }
}
