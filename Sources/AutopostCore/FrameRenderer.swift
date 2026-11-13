import CoreGraphics
import CoreImage
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

    /// `images` are the cropped photos of `layout.imageRects`, in the same order. Each fills its rect, centred.
    public static func render(
        images: [CGImage], layout: FrameLayout, frame: FrameSettings, caption: String?, textBoxes: [TextBox], isSharpening: Bool
    ) -> CGImage? {
        let width = Int(layout.canvasSize.width.rounded())
        let height = Int(layout.canvasSize.height.rounded())
        guard let first = images.first, let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        context.interpolationQuality = .high
        drawBackground(in: context, canvas: canvas, image: first, frame: frame)

        for (index, (image, rect)) in zip(images, layout.imageRects).enumerated() {
            let radius = layout.blurRadii.indices.contains(index) ? layout.blurRadii[index] : 0
            // The radius is in canvas pixels; the photo is blurred at its own size, before it is scaled to its rect.
            let fill = max(rect.width / Double(image.width), rect.height / Double(image.height))
            let sharp = isSharpening && radius == 0 ? sharpened(image) ?? image : image
            let photo = radius > 0 ? blurred(sharp, sigma: radius / fill) ?? sharp : sharp
            let mat = layout.matRects.indices.contains(index) && layout.matRects[index] != rect ? layout.matRects[index] : nil
            draw(
                photo, filling: flipped(rect, canvasHeight: canvas.height), mat: mat.map { flipped($0, canvasHeight: canvas.height) },
                in: context, frame: frame, slideWidth: canvas.width / Double(max(layout.slideCount, 1))
            )
        }

        let captionBoxes = caption.flatMap { frame.captionBox($0, in: layout) }.map { [$0] } ?? []
        TextBoxRenderer.draw(captionBoxes + textBoxes, in: context, canvasSize: canvas.size, slideCount: layout.slideCount)

        return context.makeImage()
    }

    /// Slide `index` cut out of a canvas rendered for a photo spread over several slides.
    public static func slide(_ index: Int, of canvas: CGImage, layout: FrameLayout) -> CGImage? {
        let scale = Double(canvas.width) / layout.canvasSize.width
        let rect = layout.slideRect(index)
        return canvas.cropping(to: CGRect(x: rect.minX * scale, y: 0, width: rect.width * scale, height: Double(canvas.height)).integral)
    }

    /// The photo scaled to cover `rect` and clipped to it, on its border `mat` when it has one, with the frame's
    /// shadow under the whole of it.
    private static func draw(
        _ image: CGImage, filling rect: CGRect, mat: CGRect?, in context: CGContext, frame: FrameSettings, slideWidth: Double
    ) {
        if frame.hasShadow {
            context.saveGState()
            context.setShadow(
                offset: CGSize(width: 0, height: -shadowOffsetFraction * slideWidth),
                blur: shadowBlurFraction * slideWidth,
                color: CGColor(gray: 0, alpha: shadowOpacity)
            )
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(mat ?? rect)
            context.restoreGState()
        }
        if let mat {
            context.setFillColor(CGColor(srgbRed: frame.color.red, green: frame.color.green, blue: frame.color.blue, alpha: 1))
            context.fill(mat)
        }

        let scale = max(rect.width / Double(image.width), rect.height / Double(image.height))
        let size = CGSize(width: Double(image.width) * scale, height: Double(image.height) * scale)
        context.saveGState()
        context.clip(to: rect)
        context.draw(image, in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
        context.restoreGState()
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

    /// The photo blurred, with its edges kept solid so no dark fringe shows where it meets the next photo.
    private static func blurred(_ image: CGImage, sigma: Double) -> CGImage? {
        let source = CIImage(cgImage: image)
        let output = source.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: source.extent)
        return ciContext.createCGImage(output, from: source.extent)
    }

    private static func sharpened(_ image: CGImage) -> CGImage? {
        let source = CIImage(cgImage: image)
        let output = source.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: sharpness])
        return ciContext.createCGImage(output, from: source.extent)
    }
}
