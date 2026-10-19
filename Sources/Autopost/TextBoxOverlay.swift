import AppKit
import AutopostCore
import SwiftUI

/// Selection outlines and dragging for the text boxes on the editor canvas. The text itself is drawn by FramedPhotoView.
struct TextBoxOverlay: View {
    let postID: Post.ID
    let photo: Photo
    let layout: FrameLayout
    let onInteract: () -> Void

    // Extra room around the text so small text is still easy to grab.
    private static let hitPadding = 8.0

    @Environment(LibraryStore.self) private var store
    @Environment(EditorSession.self) private var editor
    @State private var dragStart: CGPoint?
    @State private var guides = TextSnapping.Result(point: .zero)

    var body: some View {
        let size = layout.canvasSize

        ZStack(alignment: .topLeading) {
            if editor.isShowingGrid || dragStart != nil {
                GridLines(size: size, guides: guides)
            }
            ForEach(photo.textBoxes) { box in
                handle(for: box, canvasSize: size)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .coordinateSpace(.named(Self.coordinateSpace))
    }

    private func handle(for box: TextBox, canvasSize: CGSize) -> some View {
        let rect = TextBoxRenderer.bounds(for: box, canvasSize: canvasSize).insetBy(dx: -Self.hitPadding, dy: -Self.hitPadding)
        let isSelected = editor.selectedTextBoxID == box.id

        return Rectangle()
            .fill(Color.white.opacity(0.001))
            .overlay {
                Rectangle()
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: isSelected ? [] : [4, 3]))
                    .opacity(isSelected ? 1 : 0.45)
            }
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .onTapGesture(count: 2) {
                editor.select(box.id, focusingText: true)
            }
            .onTapGesture {
                editor.select(box.id)
                onInteract()
            }
            .gesture(drag(box, canvasSize: canvasSize))
            .contextMenu { menu(for: box) }
            .help("Drag to move. Hold Shift to place freely without snapping.")
    }

    private func drag(_ box: TextBox, canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(TextBoxOverlay.coordinateSpace))
            .onChanged { value in
                let start = dragStart ?? CGPoint(x: box.x, y: box.y)
                if dragStart == nil {
                    dragStart = start
                    editor.select(box.id)
                    onInteract()
                }

                let moved = CGPoint(
                    x: start.x + value.translation.width / canvasSize.width,
                    y: start.y + value.translation.height / canvasSize.height
                )
                // Shift means free placement, as in most design tools.
                let isFree = NSEvent.modifierFlags.contains(.shift)
                guides = isFree ? TextSnapping.Result(point: moved) : TextSnapping.snap(moved, layout: layout)

                var updated = box
                updated.x = guides.point.x
                updated.y = guides.point.y
                store.updateTextBox(updated, on: photo.id, in: postID)
            }
            .onEnded { _ in
                dragStart = nil
                guides = TextSnapping.Result(point: .zero)
            }
    }

    @ViewBuilder
    private func menu(for box: TextBox) -> some View {
        Button("Copy") { store.copyTextBoxToPasteboard(box) }
        Button("Duplicate") {
            var copy = box.duplicated()
            copy.y += 0.05
            store.updatePhoto(photo.id, in: postID) { $0.textBoxes.append(copy) }
            editor.select(copy.id)
        }
        Button("Copy to All Photos in Post") { store.copyTextBoxToAllPhotos(box, from: photo.id, in: postID) }
        Divider()
        Button("Delete", role: .destructive) {
            store.deleteTextBox(box.id, on: photo.id, in: postID)
            editor.select(nil)
        }
    }

    static let coordinateSpace = "editorCanvas"
}

/// The snapping grid, with the lines a box has snapped to drawn in the accent colour.
private struct GridLines: View {
    let size: CGSize
    let guides: TextSnapping.Result

    var body: some View {
        Canvas { context, _ in
            let divisions = TextSnapping.gridDivisions
            var grid = Path()
            for step in 1..<divisions {
                let fraction = Double(step) / Double(divisions)
                grid.move(to: CGPoint(x: fraction * size.width, y: 0))
                grid.addLine(to: CGPoint(x: fraction * size.width, y: size.height))
                grid.move(to: CGPoint(x: 0, y: fraction * size.height))
                grid.addLine(to: CGPoint(x: size.width, y: fraction * size.height))
            }
            // Grey with a little alpha reads on both white and black frames.
            context.stroke(grid, with: .color(.gray.opacity(0.35)), lineWidth: 0.5)

            var snapped = Path()
            if let x = guides.xGuide {
                snapped.move(to: CGPoint(x: x * size.width, y: 0))
                snapped.addLine(to: CGPoint(x: x * size.width, y: size.height))
            }
            if let y = guides.yGuide {
                snapped.move(to: CGPoint(x: 0, y: y * size.height))
                snapped.addLine(to: CGPoint(x: size.width, y: y * size.height))
            }
            context.stroke(snapped, with: .color(.accentColor), lineWidth: 1)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}
