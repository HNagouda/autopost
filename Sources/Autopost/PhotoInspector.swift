import AppKit
import AutopostCore
import SwiftUI

/// Settings for the photo open in the editor: its own border and position, and its text boxes.
struct PhotoInspector: View {
    let postID: Post.ID
    let photoID: Photo.ID

    @Environment(LibraryStore.self) private var store
    @Environment(EditorSession.self) private var editor
    @Environment(ThumbnailStore.self) private var thumbnails
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system

    var body: some View {
        if let post = store.post(postID), let photo = store.photo(photoID, in: postID) {
            Form {
                adjustments(photo: photo, post: post)
                cameraSettings(photo: photo, post: post)
                textBoxes(photo: photo)
                if let boxID = editor.selectedTextBoxID, let box = photo.textBoxes.first(where: { $0.id == boxID }) {
                    TextBoxInspector(postID: postID, photoID: photoID, box: box)
                }
            }
            .formStyle(.grouped)
            .amoledBackground(theme)
        }
    }

    private func adjustments(photo: Photo, post: Post) -> some View {
        let frame = post.frame(for: photo)

        return Section {
            LabeledContent("Border") {
                Slider(value: adjustment(\.borderPercent, current: frame.borderPercent), in: 0...FrameLayout.maxBorderPercent)
                SliderValueField(
                    value: adjustment(\.borderPercent, current: frame.borderPercent),
                    range: 0...FrameLayout.maxBorderPercent, fractionDigits: 1, unit: "%", width: 52
                )
            }
            LabeledContent("Vertical") {
                Slider(value: adjustment(\.verticalOffset, current: frame.verticalOffset), in: -1...1)
            }
            LabeledContent("Horizontal") {
                Slider(value: adjustment(\.horizontalOffset, current: frame.horizontalOffset), in: -1...1)
            }
            LabeledContent("Crop") {
                Button(photo.crop.isFull ? "Crop…" : "Edit Crop…") { editor.crop(photoID, in: store, postID: postID) }
                    .help("Crop this photo (C)")
                if !photo.crop.isFull {
                    Button("Remove") { store.updatePhoto(photoID, in: postID) { $0.crop = .full } }
                }
            }
            Button("Match Post Frame") {
                store.updatePhoto(photoID, in: postID) { $0.adjustments = PhotoAdjustments() }
            }
            .disabled(photo.adjustments.isEmpty)
        } header: {
            Text("This photo")
        } footer: {
            Text(photo.adjustments.isEmpty
                 ? "Uses the post's border. Ratio and colour are shared by the whole carousel."
                 : "Adjusted for this photo only.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    /// The settings the caption prints for this photo. Grey prompts show the EXIF, with the camera renamed; anything
    /// typed replaces it for this photo only.
    private func cameraSettings(photo: Photo, post: Post) -> some View {
        let exif = photo.cameraSettings(exif: thumbnails.thumbnail(for: photo.url)?.exif ?? CameraSettings(), cameraNames: store.library.cameraNames)
        let missing = "None"

        return Section {
            TextField("Camera", text: cameraField(\.camera), prompt: Text(exif.camera ?? missing))
            TextField("Focal length", text: cameraField(\.focalLength), prompt: Text(exif.focalLength ?? "35mm"))
            TextField("Aperture", text: cameraField(\.aperture), prompt: Text(exif.aperture ?? "ƒ/2.8"))
            TextField("Shutter", text: cameraField(\.shutter), prompt: Text(exif.shutter ?? "1/250s"))
            TextField("ISO", text: cameraField(\.iso), prompt: Text(exif.iso ?? "ISO 400"))
            HStack {
                Button("Use for All Photos") { store.copyCameraSettingsToAllPhotos(from: photoID, in: postID) }
                    .help("Gives every photo in this post the settings typed here, for a roll shot on one camera")
                Spacer()
                Button("Clear") { store.updatePhoto(photoID, in: postID) { $0.cameraOverrides = CameraSettings() } }
                    .disabled(photo.cameraOverrides.isEmpty)
            }
        } header: {
            Text("Camera settings")
        } footer: {
            Text(post.frame.captionMode == .exif
                 ? "Grey text comes from the photo. Type over it to change what prints under this photo."
                 : "Printed under the photo when the post's caption is set to Camera settings.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    /// Empty text means "use the EXIF", so clearing a field brings the photo's own value back.
    private func cameraField(_ keyPath: WritableKeyPath<CameraSettings, String?>) -> Binding<String> {
        Binding(
            get: { store.photo(photoID, in: postID)?.cameraOverrides[keyPath: keyPath] ?? "" },
            set: { text in store.updatePhoto(photoID, in: postID) { $0.cameraOverrides[keyPath: keyPath] = text.isEmpty ? nil : text } }
        )
    }

    /// A slider binding that shows the effective value and stores what the user sets as this photo's own.
    private func adjustment(_ keyPath: WritableKeyPath<PhotoAdjustments, Double?>, current: Double) -> Binding<Double> {
        Binding(
            get: { current },
            set: { value in store.updatePhoto(photoID, in: postID) { $0.adjustments[keyPath: keyPath] = value } }
        )
    }

    private func textBoxes(photo: Photo) -> some View {
        Section("Text") {
            ForEach(photo.textBoxes) { box in
                let isSelected = editor.selectedTextBoxID == box.id
                HStack {
                    Image(systemName: "textformat")
                    Text(box.text.isEmpty ? "Empty text" : box.text).lineLimit(1)
                    Spacer()
                }
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .contentShape(Rectangle())
                .onTapGesture { editor.select(box.id) }
            }
            Button("Add Text Box", systemImage: "plus") { editor.addTextBox(in: store, postID: postID) }
                .help("New boxes copy the last one you placed, in the same spot (⌘T)")
        }
    }
}

private struct TextBoxInspector: View {
    let postID: Post.ID
    let photoID: Photo.ID
    let box: TextBox

    @Environment(LibraryStore.self) private var store
    @Environment(EditorSession.self) private var editor
    @FocusState private var isTextFocused: Bool

    var body: some View {
        Section("Selected text") {
            TextEditor(text: binding(\.text))
                .font(.body)
                .frame(minHeight: 54, maxHeight: 110)
                .focused($isTextFocused)
                .onChange(of: editor.wantsTextFocus, initial: true) {
                    guard editor.wantsTextFocus else { return }
                    isTextFocused = true
                    editor.wantsTextFocus = false
                }

            TextStyleControls(
                fontFamily: binding(\.fontFamily), size: binding(\.size),
                isBold: binding(\.isBold), isItalic: binding(\.isItalic), tracking: binding(\.tracking)
            ) {
                Picker("Alignment", selection: binding(\.alignment)) {
                    Image(systemName: "text.alignleft").tag(TextBoxAlignment.leading)
                    Image(systemName: "text.aligncenter").tag(TextBoxAlignment.center)
                    Image(systemName: "text.alignright").tag(TextBoxAlignment.trailing)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            ColorSwatchRow(color: binding(\.color), swatches: ColorSwatchRow.textColors)

            HStack {
                Button("Copy to All Photos") { store.copyTextBoxToAllPhotos(box, from: photoID, in: postID) }
                    .help("Adds this text, in the same place, to every other photo in the post")
                Spacer()
                Button("Delete", role: .destructive) {
                    store.deleteTextBox(box.id, on: photoID, in: postID)
                    editor.select(nil)
                }
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<TextBox, Value>) -> Binding<Value> {
        Binding(
            get: { box[keyPath: keyPath] },
            set: { value in
                var updated = box
                updated[keyPath: keyPath] = value
                store.updateTextBox(updated, on: photoID, in: postID)
            }
        )
    }
}
