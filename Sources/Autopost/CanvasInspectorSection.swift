import AutopostCore
import SwiftUI

/// Settings for the canvas open in the editor: its slides, a ready-made arrangement, and the selected photo.
struct CanvasInspectorSection: View {
    let postID: Post.ID
    let photo: Photo

    @Environment(LibraryStore.self) private var store
    @Environment(EditorSession.self) private var editor
    // The arrangement Shuffle repeats. A new canvas is made with Overlay.
    @State private var lastTemplate = CanvasTemplate.overlay

    var body: some View {
        Section {
            LabeledContent("Slides") {
                Stepper(
                    "\(photo.slideCount)",
                    value: Binding(get: { photo.slideCount }, set: { store.setCanvasSlideCount($0, of: photo.id, in: postID) }),
                    in: 1...Photo.maxCanvasSlides
                )
                .monospacedDigit()
                .help("How many slides the canvas runs over. Instagram allows 20 in one post.")
            }
            LabeledContent("Arrange") {
                Menu(photo.gridSpacing == nil ? lastTemplate.label : CanvasTemplate.grid.label) {
                    ForEach(CanvasTemplate.allCases) { template in
                        Button("\(template.label): \(template.summary)") {
                            lastTemplate = template
                            store.arrangeCanvas(photo.id, in: postID, as: template)
                        }
                    }
                }
                .fixedSize()
                .help("Place every photo anew in a ready-made arrangement. Each can still be moved afterwards.")
                Button("Shuffle", systemImage: "shuffle") { store.arrangeCanvas(photo.id, in: postID, as: lastTemplate) }
                    .labelStyle(.iconOnly)
                    // A grid has one layout for its photos and slides, so there is nothing to shuffle.
                    .disabled(photo.gridSpacing != nil)
                    .help("Try another variation of this arrangement (⌘Z brings the last one back)")
            }
            if let spacing = photo.gridSpacing {
                LabeledContent("Spacing") {
                    Slider(value: gridSpacing(spacing), in: CanvasGrid.spacingRange)
                        .help("The space around and between the photos of the grid")
                    SliderValueField(value: gridSpacing(spacing), range: CanvasGrid.spacingRange, scale: 100, fractionDigits: 1, unit: "%", width: 52)
                }
                LabeledContent("Grid") {
                    Button("Edit Freely") { store.editCanvasFreely(photo.id, in: postID) }
                        .help("Keep the photos where they are and move or resize each by hand. Arrange > Grid makes it a grid again.")
                }
            }
            // Side by side at equal widths, so neither wraps onto a second line in a narrow sidebar.
            HStack {
                Button { store.addPhotos(FileImport.choosePhotos(allowsFolders: false), toCanvas: photo.id, in: postID) } label: {
                    Text("Add Photos…").frame(maxWidth: .infinity)
                }
                Button { store.breakCanvasApart(photo.id, in: postID) } label: {
                    Text("Break Apart").frame(maxWidth: .infinity)
                }
                .help("Give each photo of the canvas its own slide again")
            }
        } header: {
            Text("This canvas · \(LibraryStore.photoCount(photo.images.count))")
        } footer: {
            Text(photo.gridSpacing == nil
                ? "Drag a photo to move it and its handles to resize it. It snaps to slide edges, the border and other photos; hold Shift to place it freely. A photo that fills its slides makes a background for the ones on top."
                : "Drag a photo onto another to swap them. Changing the slides or the spacing lays the grid out again.")
                .font(.caption).foregroundStyle(.secondary)
        }

        if let index = editor.selectedImageIndex, photo.images.indices.contains(index) {
            selectedPhoto(index)
        }
    }

    private func gridSpacing(_ spacing: Double) -> Binding<Double> {
        Binding(get: { spacing }, set: { store.setCanvasGridSpacing($0, of: photo.id, in: postID) })
    }

    private func blur(_ index: Int) -> Binding<Double> {
        Binding(
            get: { photo.boxes[index].blur },
            set: { blur in
                var box = photo.boxes[index]
                box.blur = blur
                store.setCanvasBox(box, at: index, of: photo.id, in: postID)
            }
        )
    }

    private func border(_ index: Int) -> Binding<Double> {
        Binding(
            get: { photo.boxes[index].border },
            set: { border in
                var box = photo.boxes[index]
                box.border = border
                store.setCanvasBox(box, at: index, of: photo.id, in: postID)
            }
        )
    }

    private func selectedPhoto(_ index: Int) -> some View {
        Section("Selected photo") {
            LabeledContent("File") {
                Text(photo.images[index].url.lastPathComponent)
                    .lineLimit(1).truncationMode(.middle)
            }
            LabeledContent("Blur") {
                Toggle("Blur", isOn: Binding(get: { photo.boxes[index].blur > 0 }, set: { blur(index).wrappedValue = $0 ? CanvasBox.defaultBlur : 0 }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help("Blur this photo, so the photos on top of it stand out")
                Slider(value: blur(index), in: 0...1)
                SliderValueField(value: blur(index), range: 0...1, scale: 100, unit: "%", width: 44)
            }
            LabeledContent("Crop") {
                Button(photo.images[index].crop.isFull ? "Crop…" : "Edit Crop…") {
                    editor.crop(photo.id, in: store, postID: postID, imageIndex: index)
                }
                .help("Choose which part of the photo shows in its box (C, or double-click the photo)")
            }
            LabeledContent("Border") {
                Slider(value: border(index), in: 0...CanvasBox.maxBorder)
                    .help("A border in the post's background colour around this photo, like the white edge of a print")
                SliderValueField(value: border(index), range: 0...CanvasBox.maxBorder, scale: 100, fractionDigits: 1, unit: "%", width: 52)
            }
            // A grid has no backgrounds and no photo over another.
            if photo.gridSpacing == nil {
                LabeledContent("Background") {
                    Button("Make Background") {
                        store.useCanvasImageAsBackground(index, of: photo.id, in: postID)
                        editor.selectImage(0)
                    }
                    .help("Stretch this photo over every slide it touches, edge to edge, and put it behind the other photos")
                }
                HStack {
                    Button {
                        store.moveCanvasImage(index, toFront: true, of: photo.id, in: postID)
                        editor.selectImage(photo.images.count - 1)
                    } label: {
                        Text("Bring to Front").frame(maxWidth: .infinity)
                    }
                    .disabled(index == photo.images.count - 1)
                    Button {
                        store.moveCanvasImage(index, toFront: false, of: photo.id, in: postID)
                        editor.selectImage(0)
                    } label: {
                        Text("Send to Back").frame(maxWidth: .infinity)
                    }
                    .disabled(index == 0)
                }
            }
            Button("Take Off the Canvas", role: .destructive) { editor.deleteSelection(in: store, postID: postID) }
                .disabled(photo.images.count < 2)
                .help("Put this photo back in the post as a slide of its own (Delete)")
        }
    }
}
