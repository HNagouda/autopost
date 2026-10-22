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

    var body: some View {
        let thumbnail = thumbnails.thumbnail(for: photo.url, isLarge: true)

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
                            handleView(handle, crop: crop, size: size, imageAspect: imageAspect)
                        }
                    }
                    .frame(width: size.width, height: size.height)
                    .coordinateSpace(.named(Self.space))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            controls(imageAspect: thumbnail.map { $0.size.width / max($0.size.height, 1) } ?? 1)
        }
        .task(id: photo.url) { await thumbnails.loadLarge(photo.url) }
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

    private func handleView(_ handle: CropHandle, crop: CropRect, size: CGSize, imageAspect: Double) -> some View {
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
                        editor.cropDraft = start.resized(handle, to: point, shape: keptShape(start, imageAspect: imageAspect), imageAspect: imageAspect)
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

    private func controls(imageAspect: Double) -> some View {
        HStack(spacing: 12) {
            Picker("Shape", selection: Binding(get: { editor.cropShape }, set: { editor.useCropShape($0, imageAspect: imageAspect) })) {
                ForEach(CropShape.allCases) { Text($0.label).tag($0) }
            }
            .fixedSize()
            .help("Keep the crop at this shape. With Free, hold Shift while dragging a corner to keep the current shape.")
            Text("Shift keeps the shape · Return applies · Esc cancels")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Reset") { editor.cropDraft = .full }
                .disabled(editor.cropDraft?.isFull ?? true)
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
}
