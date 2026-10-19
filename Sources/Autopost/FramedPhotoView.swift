import AutopostCore
import SwiftUI

/// A photo on its frame, laid out by the same FrameLayout the exporter uses, so the preview is the export.
struct FramedPhotoView: View {
    let photo: Photo
    let frame: FrameSettings

    @Environment(ThumbnailStore.self) private var thumbnails

    var body: some View {
        let thumbnail = thumbnails.thumbnail(for: photo.url)
        let caption = frame.caption(exifLine: thumbnail?.exifLine)
        let imageSize = Self.imageSize(thumbnail)

        GeometryReader { geometry in
            let width = geometry.size.width
            let layout = FrameLayout(imageSize: imageSize, frame: frame, canvasWidth: width, hasCaption: caption != nil)

            ZStack(alignment: .topLeading) {
                background(thumbnail, layout: layout)
                photoLayer(thumbnail, layout: layout)
                if let caption, let rect = layout.captionRect {
                    captionLayer(caption, rect: rect, width: width)
                }
            }
            .frame(width: width, height: layout.canvasSize.height)
            .clipped()
        }
        .aspectRatio(Self.canvasRatio(thumbnail, frame: frame), contentMode: .fit)
        .task(id: photo.url) { await thumbnails.load(photo.url) }
    }

    // Before the thumbnail loads, a 3:2 stand-in keeps the tile from jumping too much.
    private static func imageSize(_ thumbnail: ThumbnailStore.Thumbnail?) -> CGSize {
        thumbnail?.size ?? CGSize(width: 3, height: 2)
    }

    /// Width over height of the framed canvas.
    static func canvasRatio(_ thumbnail: ThumbnailStore.Thumbnail?, frame: FrameSettings) -> Double {
        let hasCaption = frame.caption(exifLine: thumbnail?.exifLine) != nil
        let unit = FrameLayout(imageSize: imageSize(thumbnail), frame: frame, canvasWidth: 1, hasCaption: hasCaption)
        return unit.canvasSize.width / unit.canvasSize.height
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

    private func captionLayer(_ caption: String, rect: CGRect, width: Double) -> some View {
        let isDarkText = frame.background == .color && frame.color.isLight
        let fontSize = FrameLayout.captionFontFraction * width
        return Text(caption)
            .font(.system(size: fontSize))
            .kerning(0.04 * fontSize)
            .foregroundStyle(Color(white: isDarkText ? 0.32 : 0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: rect.width, height: rect.height)
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
