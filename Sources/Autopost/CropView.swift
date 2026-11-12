import AppKit
import AutopostCore
import SwiftUI

/// The shapes offered while cropping.
enum CropShape: String, CaseIterable, Identifiable {
    case free
    case original
    case square
    case portrait4x5
    case portrait2x3
    case portrait9x16
    case landscape5x4
    case landscape3x2
    case landscape16x9

    var id: String { rawValue }

    var label: String {
        switch self {
        case .free: "Free"
        case .original: "Original"
        case .square: "1:1"
        case .portrait4x5: "4:5"
        case .portrait2x3: "2:3"
        case .portrait9x16: "9:16"
        case .landscape5x4: "5:4"
        case .landscape3x2: "3:2"
        case .landscape16x9: "16:9"
        }
    }

    /// Width over height in pixels, or nil when the crop is free.
    func ratio(imageAspect: Double) -> Double? {
        switch self {
        case .free: nil
        case .original: imageAspect
        case .square: 1
        case .portrait4x5: 4.0 / 5.0
        case .portrait2x3: 2.0 / 3.0
        case .portrait9x16: 9.0 / 16.0
        case .landscape5x4: 5.0 / 4.0
        case .landscape3x2: 3.0 / 2.0
        case .landscape16x9: 16.0 / 9.0
        }
    }
}

/// The open photo uncropped, with the crop drawn over it to drag. Takes the framed canvas's place while cropping.
struct CropView: View {
    let postID: Post.ID
    let photo: Photo

    private static let padding = 40.0
    private static let space = "crop"
    // The visible handle, and the larger square around it that a click still grabs.
    private static let handleSize = 12.0
    private static let handleHitSize = 28.0
    private static let shadeOpacity = 0.6

    @Environment(LibraryStore.self) private var store
    @Environment(EditorSession.self) private var editor
    @Environment(ThumbnailStore.self) private var thumbnails
    // The crop when the current drag began; every drag step is worked out from it.
    @State private var dragStart: CropRect?

    // The photo of the stack being cropped, or the photo itself.
    private var image: Photo {
        photo.images.indices.contains(editor.cropImageIndex) ? photo.images[editor.cropImageIndex] : photo
    }

    var body: some View {
        let thumbnail = thumbnails.thumbnail(for: image.url, isLarge: true)
        let lockedShape = filledShape()

        VStack(spacing: 0) {
            GeometryReader { geometry in
                if let thumbnail, let crop = editor.cropDraft {
                    let size = Self.fitted(thumbnail.size, in: geometry.size)
                    let imageAspect = thumbnail.size.width / max(thumbnail.size.height, 1)

                    ZStack(alignment: .topLeading) {
                        Image(decorative: thumbnail.image, scale: 1)
                            .resizable()
                            .interpolation(.high)
                        shade(crop, size: size)
                        cropFrame(crop, size: size)
                        ForEach(CropHandle.allCases, id: \.self) { handle in
                            handleView(handle, crop: crop, size: size, imageAspect: imageAspect, lockedShape: lockedShape)
                        }
                    }
                    .frame(width: size.width, height: size.height)
                    .coordinateSpace(.named(Self.space))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            controls(thumbnail: thumbnail, lockedShape: lockedShape)
        }
        .task(id: image.url) { await thumbnails.loadLarge(image.url) }
        // A stacked photo only ever shows the part of its crop that fills its place, so the crop starts as that part.
        .onChange(of: lockedShape, initial: true) { fitDraft(to: lockedShape, thumbnail: thumbnail) }
        .onChange(of: thumbnail?.size) { fitDraft(to: lockedShape, thumbnail: thumbnail) }
        .onChange(of: editor.cropImageIndex) { fitDraft(to: lockedShape, thumbnail: thumbnail) }
    }

    /// Sets the crop to just inside a margin found in the file, kept at the locked shape when there is one.
    private func trimEdges(thumbnail: ThumbnailStore.Thumbnail?, lockedShape: Double?) {
        guard let thumbnail else { return }
        guard let trimmed = EdgeTrim.crop(removingBorderOf: thumbnail.image) else {
            store.toast = Toast(message: "No plain margin found around this photo", systemImage: "crop")
            return
        }
        let imageAspect = thumbnail.size.width / max(thumbnail.size.height, 1)
        editor.cropDraft = lockedShape.map { trimmed.filled(toShape: $0, imageAspect: imageAspect) } ?? trimmed
    }

    private func fitDraft(to lockedShape: Double?, thumbnail: ThumbnailStore.Thumbnail?) {
        guard let lockedShape, let thumbnail, let draft = editor.cropDraft else { return }
        editor.cropDraft = draft.filled(toShape: lockedShape, imageAspect: thumbnail.size.width / max(thumbnail.size.height, 1))
    }

    /// The shape of the open photo's place in its stack or panorama, which the crop must keep, or nil when it may be any shape.
    /// With the original ratio the photo keeps its own shape, so its crop stays free there too.
    private func filledShape() -> Double? {
        guard photo.isStack || photo.slideCount > 1, let post = store.post(postID) else { return nil }
        let frame = post.frame(for: photo)
        guard frame.ratioValue != nil else { return nil }

        let loaded = FramedPhotoView.loadedThumbnails(for: photo, in: thumbnails)
        let layout = FramedPhotoView.layout(photo: photo, frame: frame, thumbnails: loaded, cameraNames: store.library.cameraNames, slideWidth: 1)
        guard layout.imageRects.indices.contains(editor.cropImageIndex) else { return nil }
        let rect = layout.imageRects[editor.cropImageIndex]
        return rect.width / max(rect.height, 0.000_001)
    }

    /// The photo's size scaled to fit the space, with room around it.
    private static func fitted(_ imageSize: CGSize, in space: CGSize) -> CGSize {
        let available = CGSize(width: max(space.width - 2 * padding, 1), height: max(space.height - 2 * padding, 1))
        let scale = min(available.width / imageSize.width, available.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    /// Darkens what the crop cuts away.
    private func shade(_ crop: CropRect, size: CGSize) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            path.addRect(crop.pixelRect(in: size))
        }
        .fill(Color.black.opacity(Self.shadeOpacity), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }

    /// The crop's outline with a rule-of-thirds grid. Dragging inside it slides the crop.
    private func cropFrame(_ crop: CropRect, size: CGSize) -> some View {
        let rect = crop.pixelRect(in: size)

        return ZStack {
            Path { path in
                for third in [1.0 / 3.0, 2.0 / 3.0] {
                    path.move(to: CGPoint(x: rect.width * third, y: 0))
                    path.addLine(to: CGPoint(x: rect.width * third, y: rect.height))
                    path.move(to: CGPoint(x: 0, y: rect.height * third))
                    path.addLine(to: CGPoint(x: rect.width, y: rect.height * third))
                }
            }
            .stroke(Color.white.opacity(0.45), lineWidth: 0.5)
            Rectangle().strokeBorder(Color.white, lineWidth: 1.5)
        }
        .contentShape(Rectangle())
        .frame(width: rect.width, height: rect.height)
        .offset(x: rect.minX, y: rect.minY)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let start = dragStart ?? crop
                    dragStart = start
                    editor.cropDraft = start.moved(byX: value.translation.width / size.width, y: value.translation.height / size.height)
                }
                .onEnded { _ in dragStart = nil }
        )
    }

    private func handleView(_ handle: CropHandle, crop: CropRect, size: CGSize, imageAspect: Double, lockedShape: Double?) -> some View {
        let rect = crop.pixelRect(in: size)
        let center = CGPoint(x: rect.minX + handle.anchor.x * rect.width, y: rect.minY + handle.anchor.y * rect.height)

        return RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.4), radius: 2)
            .frame(width: Self.handleSize, height: Self.handleSize)
            .frame(width: Self.handleHitSize, height: Self.handleHitSize)
            .contentShape(Rectangle())
            .offset(x: center.x - Self.handleHitSize / 2, y: center.y - Self.handleHitSize / 2)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        let start = dragStart ?? crop
                        dragStart = start
                        let point = CGPoint(x: value.location.x / size.width, y: value.location.y / size.height)
                        editor.cropDraft = start.resized(handle, to: point, shape: lockedShape ?? keptShape(start, imageAspect: imageAspect), imageAspect: imageAspect)
                    }
                    .onEnded { _ in dragStart = nil }
            )
    }

    /// The chosen shape, or with a free crop and Shift held, the shape the crop had when the drag began.
    private func keptShape(_ start: CropRect, imageAspect: Double) -> Double? {
        if let ratio = editor.cropShape.ratio(imageAspect: imageAspect) { return ratio }
        guard NSEvent.modifierFlags.contains(.shift) else { return nil }
        return start.width * imageAspect / max(start.height, CropRect.minimumSide)
    }

    private func controls(thumbnail: ThumbnailStore.Thumbnail?, lockedShape: Double?) -> some View {
        let imageAspect = thumbnail.map { $0.size.width / max($0.size.height, 1) } ?? 1
        let frame = store.post(postID)?.frame ?? FrameSettings()

        return HStack(spacing: 12) {
            if photo.isStack {
                Picker("Photo", selection: Binding(get: { editor.cropImageIndex }, set: { editor.cropImage($0, in: store, postID: postID) })) {
                    ForEach(photo.images.indices, id: \.self) { Text(Self.stackPlaceLabel($0, count: photo.images.count)).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .help("Which photo of the stack to crop")
            }
            if lockedShape == nil {
                Picker("Shape", selection: Binding(get: { editor.cropShape }, set: { editor.useCropShape($0, imageAspect: imageAspect) })) {
                    ForEach(CropShape.allCases) { Text($0.label).tag($0) }
                }
                .fixedSize()
                .help("Keep the crop at this shape. With Free, hold Shift while dragging a corner to keep the current shape.")
                Text("Shift keeps the shape · Return applies · Esc cancels")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // The crop has to keep the shape of its place on the slides, so the slides' ratio is what can change.
                Picker("Slides", selection: store.frameBinding(for: postID).ratio) {
                    ForEach(AspectRatio.allCases.filter { $0 != .custom || frame.ratio == .custom }) { Text($0.label).tag($0) }
                }
                .fixedSize()
                .help("The aspect ratio of every slide in this post, which sets the shape of this crop")
                Text("\(photo.isStack ? "The stack" : "The split photo") sets the shape · Return applies · Esc cancels")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Trim White Edges") { trimEdges(thumbnail: thumbnail, lockedShape: lockedShape) }
                .disabled(thumbnail == nil)
                .help("Crop off a plain margin baked into the file, like the white border of a scan")
            Button("Reset") { editor.cropDraft = lockedShape.map { CropRect.full.filled(toShape: $0, imageAspect: imageAspect) } ?? .full }
                .disabled(editor.cropDraft == (lockedShape.map { CropRect.full.filled(toShape: $0, imageAspect: imageAspect) } ?? .full))
            Button("Cancel") { editor.cancelCrop() }
            Button("Apply Crop") { editor.applyCrop(in: store, postID: postID) }
                .buttonStyle(.borderedProminent)
        }
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    /// "Top", "Middle", "Bottom" for a stack of three; "Top", "Bottom" for two.
    private static func stackPlaceLabel(_ index: Int, count: Int) -> String {
        if index == 0 { return "Top" }
        return index == count - 1 ? "Bottom" : "Middle"
    }
}
