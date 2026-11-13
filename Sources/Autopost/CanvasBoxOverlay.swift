import AppKit
import AutopostCore
import SwiftUI

/// Selecting, moving and resizing the photos of a canvas in the editor. The photos themselves are drawn by
/// FramedPhotoView from the same boxes, so what is dragged here is what gets exported.
struct CanvasBoxOverlay: View {
    let postID: Post.ID
    let photo: Photo
    let layout: FrameLayout
    let onInteract: () -> Void

    // How close a dragged edge must come to a line before it snaps, in points on screen.
    private static let snapDistance = 6.0
    private static let space = "canvasBoxes"
    private static let handleSize = 9.0
    // The area that takes the drag is larger than the square drawn, so a handle is easy to grab.
    private static let handleHitSize = 18.0

    @Environment(LibraryStore.self) private var store
    @Environment(EditorSession.self) private var editor
    // The box as it was when the current drag began; every drag step is worked out from it.
    @State private var dragStart: CanvasBox?
    @State private var guides = CanvasSnapping.Result(box: CanvasBox(x: 0, y: 0, width: 1, height: 1))
    // In a grid, the photo the dragged one is over and would swap with.
    @State private var swapTarget: Int?

    private var slideWidth: Double { layout.canvasSize.width / Double(layout.slideCount) }
    private var slideHeight: Double { layout.canvasSize.height }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(photo.boxes.enumerated()), id: \.offset) { index, box in
                boxView(box, index: index)
            }
            if dragStart != nil { guideLines }
            // A grid sets every photo's size, so there is nothing to resize.
            if photo.gridSpacing == nil, let index = editor.selectedImageIndex, photo.boxes.indices.contains(index) {
                ForEach(CanvasSnapping.Handle.all, id: \.self) { handle in
                    handleView(handle, box: photo.boxes[index], index: index)
                }
            }
        }
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height, alignment: .topLeading)
        .coordinateSpace(.named(Self.space))
    }

    private func rect(_ box: CanvasBox) -> CGRect {
        CGRect(x: box.x * slideWidth, y: box.y * slideHeight, width: box.width * slideWidth, height: box.height * slideHeight)
    }

    private func boxView(_ box: CanvasBox, index: Int) -> some View {
        let rect = rect(box)
        let isSelected = editor.selectedImageIndex == index

        return Rectangle()
            .fill(Color.white.opacity(0.001))
            .overlay { Rectangle().strokeBorder(Color.accentColor, lineWidth: swapTarget == index ? 4 : isSelected ? 2 : 0) }
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .onTapGesture(count: 2) { editor.crop(photo.id, in: store, postID: postID, imageIndex: index) }
            .onTapGesture {
                editor.selectImage(index)
                onInteract()
            }
            .gesture(photo.gridSpacing == nil ? AnyGesture(moveDrag(box, index: index).map { _ in }) : AnyGesture(swapDrag(box, index: index).map { _ in }))
            .contextMenu { menu(index: index) }
            .help(photo.gridSpacing == nil
                ? "Drag to move, double-click to choose which part of the photo shows. Hold Shift to place freely."
                : "Drag onto another photo to swap them, double-click to choose which part of the photo shows.")
    }

    private func handleView(_ handle: CanvasSnapping.Handle, box: CanvasBox, index: Int) -> some View {
        let rect = rect(box)
        let x = rect.midX + Double(handle.horizontal) * rect.width / 2
        let y = rect.midY + Double(handle.vertical) * rect.height / 2

        return Rectangle()
            .fill(Color.white)
            .overlay { Rectangle().strokeBorder(Color.accentColor, lineWidth: 1.5) }
            .frame(width: Self.handleSize, height: Self.handleSize)
            .frame(width: Self.handleHitSize, height: Self.handleHitSize)
            .contentShape(Rectangle())
            .offset(x: x - Self.handleHitSize / 2, y: y - Self.handleHitSize / 2)
            .gesture(resizeDrag(handle, box: box, index: index))
    }

    private func moveDrag(_ box: CanvasBox, index: Int) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
            .onChanged { value in
                let start = begin(box, index: index)
                var moved = start
                moved.x += value.translation.width / slideWidth
                moved.y += value.translation.height / slideHeight

                // Shift means free placement, as for text boxes.
                guides = NSEvent.modifierFlags.contains(.shift)
                    ? CanvasSnapping.Result(box: moved)
                    : CanvasSnapping.moved(moved, lines: lines(without: index), thresholdX: Self.snapDistance / slideWidth, thresholdY: Self.snapDistance / slideHeight)
                store.setCanvasBox(guides.box, at: index, of: photo.id, in: postID)
            }
            .onEnded { _ in end() }
    }

    /// In a grid a drag carries the photo along and, dropped on another photo, swaps the two.
    private func swapDrag(_ box: CanvasBox, index: Int) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
            .onChanged { value in
                let start = begin(box, index: index)
                var moved = start
                moved.x += value.translation.width / slideWidth
                moved.y += value.translation.height / slideHeight

                swapTarget = photo.boxes.indices.first { other in
                    let cell = photo.boxes[other]
                    return other != index && cell.x <= moved.midX && moved.midX <= cell.maxX && cell.y <= moved.midY && moved.midY <= cell.maxY
                }
                store.setCanvasBox(moved, at: index, of: photo.id, in: postID)
            }
            .onEnded { _ in
                store.dropCanvasImage(index, onto: swapTarget, of: photo.id, in: postID)
                if let swapTarget { editor.selectImage(swapTarget) }
                swapTarget = nil
                end()
            }
    }

    private func resizeDrag(_ handle: CanvasSnapping.Handle, box: CanvasBox, index: Int) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                let start = begin(box, index: index)
                guides = CanvasSnapping.resized(
                    start, handle: handle, byX: value.translation.width / slideWidth, y: value.translation.height / slideHeight,
                    lines: NSEvent.modifierFlags.contains(.shift) ? nil : lines(without: index),
                    thresholdX: Self.snapDistance / slideWidth, thresholdY: Self.snapDistance / slideHeight
                )
                store.setCanvasBox(guides.box, at: index, of: photo.id, in: postID)
            }
            .onEnded { _ in end() }
    }

    /// The box the drag started from, remembered on the first step.
    private func begin(_ box: CanvasBox, index: Int) -> CanvasBox {
        if let dragStart { return dragStart }
        dragStart = box
        editor.selectImage(index)
        onInteract()
        return box
    }

    private func end() {
        dragStart = nil
        guides = CanvasSnapping.Result(box: guides.box)
    }

    /// The post's border is the margin photos snap to inside each slide, so a canvas lines up with the framed
    /// photos before and after it.
    private func lines(without index: Int) -> CanvasSnapping.Lines {
        let border = (store.post(postID)?.frame.borderPercent ?? 0) / 100
        let others = photo.boxes.enumerated().filter { $0.offset != index }.map(\.element)
        return CanvasSnapping.lines(
            slideCount: photo.slideCount, marginX: border, marginY: border * slideWidth / max(slideHeight, 1), others: others
        )
    }

    private var guideLines: some View {
        Path { path in
            if let x = guides.xGuide {
                path.move(to: CGPoint(x: x * slideWidth, y: 0))
                path.addLine(to: CGPoint(x: x * slideWidth, y: slideHeight))
            }
            if let y = guides.yGuide {
                path.move(to: CGPoint(x: 0, y: y * slideHeight))
                path.addLine(to: CGPoint(x: layout.canvasSize.width, y: y * slideHeight))
            }
        }
        .stroke(Color.accentColor, lineWidth: 1)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func menu(index: Int) -> some View {
        Button("Crop Photo") { editor.crop(photo.id, in: store, postID: postID, imageIndex: index) }
        Divider()
        if photo.gridSpacing == nil {
            Button("Bring to Front") { moveImage(index, toFront: true) }
                .disabled(index == photo.images.count - 1)
            Button("Send to Back") { moveImage(index, toFront: false) }
                .disabled(index == 0)
            Divider()
        }
        Button("Take Off the Canvas", role: .destructive) {
            store.removeCanvasImage(index, of: photo.id, in: postID)
            editor.selectedImageIndex = nil
        }
        .disabled(photo.images.count < 2)
    }

    private func moveImage(_ index: Int, toFront: Bool) {
        store.moveCanvasImage(index, toFront: toFront, of: photo.id, in: postID)
        editor.selectImage(toFront ? photo.images.count - 1 : 0)
    }
}
