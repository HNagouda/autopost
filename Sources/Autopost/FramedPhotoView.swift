import AutopostCore
import SwiftUI

/// A photo on its frame, laid out by the same FrameLayout the exporter uses, so the preview is the export.
struct FramedPhotoView: View {
    let photo: Photo
    // The post's frame. The photo's own border and position are applied on top here, as the exporter does.
    let postFrame: FrameSettings
    var isLarge = false

    @Environment(ThumbnailStore.self) private var thumbnails

    init(photo: Photo, frame: FrameSettings, isLarge: Bool = false) {
        self.photo = photo
        self.postFrame = frame
        self.isLarge = isLarge
    }

    private var frame: FrameSettings {
        postFrame.applying(photo.adjustments)
    }

    var body: some View {
        let thumbnail = thumbnails.thumbnail(for: photo.url, isLarge: isLarge)

        GeometryReader { geometry in
            let width = geometry.size.width
            let layout = Self.layout(photo: photo, frame: frame, thumbnail: thumbnail, width: width)

            ZStack(alignment: .topLeading) {
                background(thumbnail, layout: layout)
                photoLayer(thumbnail, layout: layout)
                let boxes = textBoxes(thumbnail, layout: layout)
                if !boxes.isEmpty {
                    textLayer(boxes, size: layout.canvasSize)
                }
            }
            .frame(width: width, height: layout.canvasSize.height)
            .clipped()
        }
        .aspectRatio(Self.canvasRatio(thumbnail, frame: frame), contentMode: .fit)
        .task(id: photo.url) {
            if isLarge { await thumbnails.loadLarge(photo.url) } else { await thumbnails.load(photo.url) }
        }
    }

    // Before the thumbnail loads, a 3:2 stand-in keeps the tile from jumping too much.
    private static func imageSize(_ thumbnail: ThumbnailStore.Thumbnail?) -> CGSize {
        thumbnail?.size ?? CGSize(width: 3, height: 2)
    }

    /// Width over height of the framed canvas.
    static func canvasRatio(_ thumbnail: ThumbnailStore.Thumbnail?, frame: FrameSettings) -> Double {
        let unit = layout(frame: frame, thumbnail: thumbnail, width: 1)
        return unit.canvasSize.width / unit.canvasSize.height
    }

    /// `frame` must already include the photo's own adjustments.
    static func layout(photo: Photo? = nil, frame: FrameSettings, thumbnail: ThumbnailStore.Thumbnail?, width: Double) -> FrameLayout {
        let hasCaption = frame.caption(exifLine: thumbnail?.exifLine) != nil
        return FrameLayout(imageSize: imageSize(thumbnail), frame: frame, canvasWidth: width, hasCaption: hasCaption)
    }

    /// The caption, when there is one, followed by the photo's own text boxes, as the exporter draws them.
    private func textBoxes(_ thumbnail: ThumbnailStore.Thumbnail?, layout: FrameLayout) -> [TextBox] {
        let caption = frame.caption(exifLine: thumbnail?.exifLine).flatMap { frame.captionBox($0, in: layout) }
        return (caption.map { [$0] } ?? []) + photo.textBoxes
    }

    /// Drawn by the exporter's own Core Text code, so line breaks and spacing match the JPEG exactly.
    private func textLayer(_ boxes: [TextBox], size: CGSize) -> some View {
        Canvas { context, canvasSize in
            context.withCGContext { cgContext in
                // Canvas has a top-left origin; the renderer expects Core Graphics' bottom-left one.
                cgContext.translateBy(x: 0, y: canvasSize.height)
                cgContext.scaleBy(x: 1, y: -1)
                TextBoxRenderer.draw(boxes, in: cgContext, canvasSize: canvasSize)
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private var frameColor: Color {
        Color(rgb: frame.color)
    }

    @ViewBuilder
    private func background(_ thumbnail: ThumbnailStore.Thumbnail?, layout: FrameLayout) -> some View {
        if frame.background == .blur, let thumbnail {
            Image(decorative: thumbnail.image, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)
                .blur(radius: FrameRenderer.blurRadiusFraction * layout.canvasSize.width, opaque: true)
                .clipped()
        } else {
            frameColor
        }
    }

    @ViewBuilder
    private func photoLayer(_ thumbnail: ThumbnailStore.Thumbnail?, layout: FrameLayout) -> some View {
        let rect = layout.imageRect
        let width = layout.canvasSize.width
        Group {
            if let thumbnail {
                Image(decorative: thumbnail.image, scale: 1)
                    .resizable()
                    .interpolation(.high)
            } else if thumbnails.missing.contains(photo.url) {
                Color.red.opacity(0.15).overlay {
                    Label("Missing", systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
            } else {
                Color.gray.opacity(0.2).overlay { ProgressView().controlSize(.small) }
            }
        }
        .frame(width: rect.width, height: rect.height)
        .shadow(
            color: .black.opacity(frame.hasShadow ? FrameRenderer.shadowOpacity : 0),
            radius: FrameRenderer.shadowBlurFraction * width / 2,
            y: FrameRenderer.shadowOffsetFraction * width
        )
        .offset(x: rect.minX, y: rect.minY)
    }
}

extension Color {
    init(rgb: FrameColor) {
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

extension FrameColor {
    init(_ color: Color) {
        let resolved = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(red: resolved.redComponent, green: resolved.greenComponent, blue: resolved.blueComponent)
    }
}
