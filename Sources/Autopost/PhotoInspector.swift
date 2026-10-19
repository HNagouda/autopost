import AppKit
import AutopostCore
import SwiftUI

/// Settings for the photo open in the editor: its own border and position, and its text boxes.
struct PhotoInspector: View {
    let postID: Post.ID
    let photoID: Photo.ID

    @Environment(LibraryStore.self) private var store
    @Environment(EditorSession.self) private var editor
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system

    var body: some View {
        if let post = store.post(postID), let photo = store.photo(photoID, in: postID) {
            Form {
                adjustments(photo: photo, post: post)
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
                Text("\(frame.borderPercent, format: .number.precision(.fractionLength(1)))%")
                    .monospacedDigit().frame(width: 44, alignment: .trailing)
            }
            LabeledContent("Vertical") {
                Slider(value: adjustment(\.verticalOffset, current: frame.verticalOffset), in: -1...1)
            }
            LabeledContent("Horizontal") {
                Slider(value: adjustment(\.horizontalOffset, current: frame.horizontalOffset), in: -1...1)
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
