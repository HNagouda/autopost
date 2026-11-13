import AutopostCore
import SwiftUI

/// A photo on its frame, laid out by the same FrameLayout the exporter uses, so the preview is the export.
///
/// Equatable, so SwiftUI skips a photo whose own settings did not change when another photo is edited.
struct FramedPhotoView: View, Equatable {
    let photo: Photo
    // The post's frame. The photo's own border and position are applied on top here, as the exporter does.
    let postFrame: FrameSettings
    var isLarge = false
    // Dashed lines where a panorama is cut into slides, for the grid and the editor. The phone shows real slides instead.
    var showsSeams = false

    @Environment(ThumbnailStore.self) private var thumbnails
    @Environment(LibraryStore.self) private var store

    init(photo: Photo, frame: FrameSettings, isLarge: Bool = false, showsSeams: Bool = false) {
        self.photo = photo
        self.postFrame = frame
        self.isLarge = isLarge
        self.showsSeams = showsSeams
    }

    nonisolated static func == (a: FramedPhotoView, b: FramedPhotoView) -> Bool {
        a.photo == b.photo && a.postFrame == b.postFrame && a.isLarge == b.isLarge && a.showsSeams == b.showsSeams
    }

    private var frame: FrameSettings {
        postFrame.applying(photo.adjustments)
    }

    var body: some View {
        let loaded = Self.loadedThumbnails(for: photo, in: thumbnails, isLarge: isLarge)
        let images = photo.images.map { thumbnails.croppedImage(for: $0.url, crop: $0.crop, isLarge: isLarge) }
        let cameraNames = store.cameraNames

        GeometryReader { geometry in
            let width = geometry.size.width
            let layout = Self.layout(photo: photo, frame: frame, thumbnails: loaded, cameraNames: cameraNames, slideWidth: width / Double(photo.slideCount))
            // The shadow is sized by one slide, as text is, so it is no larger on a canvas of many slides.
            let slideWidth = layout.canvasSize.width / Double(max(layout.slideCount, 1))

            ZStack(alignment: .topLeading) {
                background(images.first ?? nil, layout: layout)
                ForEach(Array(photo.images.enumerated()), id: \.element.id) { index, image in
                    // A photo of a canvas with a border sits on a mat in the frame colour, which carries the shadow.
                    let mat = layout.matRects.indices.contains(index) && layout.matRects[index] != layout.imageRects[index] ? layout.matRects[index] : nil
                    if let mat {
                        frameColor
                            .frame(width: mat.width, height: mat.height)
                            .shadow(
                                color: .black.opacity(frame.hasShadow ? FrameRenderer.shadowOpacity : 0),
                                radius: FrameRenderer.shadowBlurFraction * slideWidth / 2,
                                y: FrameRenderer.shadowOffsetFraction * slideWidth
                            )
                            .offset(x: mat.minX, y: mat.minY)
                    }
                    photoLayer(
                        images[index], url: image.url, rect: layout.imageRects[index], slideWidth: slideWidth, hasShadow: mat == nil,
                        blurRadius: layout.blurRadii.indices.contains(index) ? layout.blurRadii[index] : 0
                    )
                }
                let boxes = textBoxes(loaded.first ?? nil, cameraNames: cameraNames, layout: layout)
                if !boxes.isEmpty {
                    textLayer(boxes, size: layout.canvasSize, slideCount: layout.slideCount)
                }
                if showsSeams && layout.slideCount > 1 {
                    seams(layout)
                }
            }
            .frame(width: width, height: layout.canvasSize.height)
            .clipped()
        }
        .aspectRatio(Self.canvasRatio(photo: photo, frame: frame, thumbnails: loaded, cameraNames: cameraNames), contentMode: .fit)
        .task(id: photo.images.map(\.url)) {
            for image in photo.images {
                if isLarge { await thumbnails.loadLarge(image.url) } else { await thumbnails.load(image.url) }
            }
        }
    }

    /// The thumbnails of `photo.images`, in order, from the store.
    static func loadedThumbnails(for photo: Photo, in store: ThumbnailStore, isLarge: Bool = false) -> [ThumbnailStore.Thumbnail?] {
        photo.images.map { store.thumbnail(for: $0.url, isLarge: isLarge) }
    }

    // Before a thumbnail loads, a 3:2 stand-in keeps the tile from jumping too much.
    private static func imageSizes(_ photo: Photo, thumbnails: [ThumbnailStore.Thumbnail?]) -> [CGSize] {
        zip(photo.images, thumbnails).map { image, thumbnail in image.crop.size(of: thumbnail?.size ?? CGSize(width: 3, height: 2)) }
    }

    /// Width over height of the whole framed canvas, every slide of a panorama included.
    static func canvasRatio(photo: Photo, frame: FrameSettings, thumbnails: [ThumbnailStore.Thumbnail?], cameraNames: [String: String]) -> Double {
        let unit = layout(photo: photo, frame: frame, thumbnails: thumbnails, cameraNames: cameraNames, slideWidth: 1)
        return unit.canvasSize.width / unit.canvasSize.height
    }

    /// `frame` must already include the photo's own adjustments. `slideWidth` is the width of one slide.
    static func layout(
        photo: Photo, frame: FrameSettings, thumbnails: [ThumbnailStore.Thumbnail?], cameraNames: [String: String], slideWidth: Double
    ) -> FrameLayout {
        let hasCaption = caption(photo: photo, frame: frame, thumbnail: thumbnails.first ?? nil, cameraNames: cameraNames) != nil
        return FrameLayout(photo: photo, imageSizes: imageSizes(photo, thumbnails: thumbnails), frame: frame, canvasWidth: slideWidth, hasCaption: hasCaption)
    }

    /// The caption text, from the EXIF and what the user typed over it, as the exporter prints it.
    static func caption(photo: Photo, frame: FrameSettings, thumbnail: ThumbnailStore.Thumbnail?, cameraNames: [String: String]) -> String? {
        let settings = photo.cameraSettings(exif: thumbnail?.exif ?? CameraSettings(), cameraNames: cameraNames)
        return frame.caption(exifLine: settings.line)
    }

    /// The caption, when there is one, followed by the photo's own text boxes, as the exporter draws them.
    private func textBoxes(_ thumbnail: ThumbnailStore.Thumbnail?, cameraNames: [String: String], layout: FrameLayout) -> [TextBox] {
        let caption = Self.caption(photo: photo, frame: frame, thumbnail: thumbnail, cameraNames: cameraNames)
            .flatMap { frame.captionBox($0, in: layout) }
        return (caption.map { [$0] } ?? []) + photo.textBoxes
    }

    /// Drawn by the exporter's own Core Text code, so line breaks and spacing match the JPEG exactly.
    private func textLayer(_ boxes: [TextBox], size: CGSize, slideCount: Int) -> some View {
        Canvas { context, canvasSize in
            context.withCGContext { cgContext in
                // Canvas has a top-left origin; the renderer expects Core Graphics' bottom-left one.
                cgContext.translateBy(x: 0, y: canvasSize.height)
                cgContext.scaleBy(x: 1, y: -1)
                TextBoxRenderer.draw(boxes, in: cgContext, canvasSize: canvasSize, slideCount: slideCount)
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private var frameColor: Color {
        Color(rgb: frame.color)
    }

    @ViewBuilder
    private func background(_ image: CGImage?, layout: FrameLayout) -> some View {
        if frame.background == .blur, let image {
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)
                .blur(radius: FrameRenderer.blurRadiusFraction * layout.canvasSize.width, opaque: true)
                .clipped()
        } else {
            frameColor
        }
    }

    /// The photo scaled to fill its rect and clipped to it, the way the exporter draws every photo.
    @ViewBuilder
    private func photoLayer(
        _ image: CGImage?, url: URL, rect: CGRect, slideWidth: Double, hasShadow: Bool, blurRadius: Double
    ) -> some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else if thumbnails.missing.contains(url) {
                Color.red.opacity(0.15).overlay {
                    Label("Missing", systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
            } else {
                Color.gray.opacity(0.2).overlay { ProgressView().controlSize(.small) }
            }
        }
        .frame(width: rect.width, height: rect.height)
        // Opaque, so the blur does not fade the photo out towards its edges.
        .blur(radius: blurRadius, opaque: true)
        .clipped()
        .shadow(
            color: .black.opacity(frame.hasShadow && hasShadow ? FrameRenderer.shadowOpacity : 0),
            radius: FrameRenderer.shadowBlurFraction * slideWidth / 2,
            y: FrameRenderer.shadowOffsetFraction * slideWidth
        )
        .offset(x: rect.minX, y: rect.minY)
    }

    private func seams(_ layout: FrameLayout) -> some View {
        Path { path in
            for index in 1..<layout.slideCount {
                let x = layout.slideRect(index).minX
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: layout.canvasSize.height))
            }
        }
        .stroke(Color.accentColor.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        .allowsHitTesting(false)
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
