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

    // Shown first; the rest of the installed families follow.
    private static let favoriteFamilies = [
        TextBox.systemFontFamily, "Helvetica Neue", "Avenir Next", "Futura", "Gill Sans", "Didot",
        "Baskerville", "Georgia", "American Typewriter", "Courier New", "Snell Roundhand",
    ]
    // Font size limits as a fraction of the canvas width.
    private static let sizeRange = 0.01...0.2
    // Reference width for showing font size in pixels, the Instagram export width.
    private static let referenceWidth = 1080.0

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

            Picker("Font", selection: binding(\.fontFamily)) {
                ForEach(Self.favoriteFamilies, id: \.self) { family in
                    Text(family == TextBox.systemFontFamily ? "System (SF Pro)" : family).tag(family)
                }
                Divider()
                ForEach(Self.otherFamilies, id: \.self) { Text($0).tag($0) }
            }

            LabeledContent("Size") {
                Slider(value: binding(\.size), in: Self.sizeRange)
                Text("\(Int((box.size * Self.referenceWidth).rounded())) px")
                    .monospacedDigit().frame(width: 48, alignment: .trailing)
                    .help("Size on a 1080 px export")
            }

            LabeledContent("Style") {
                Toggle(isOn: binding(\.isBold)) { Image(systemName: "bold") }
                    .toggleStyle(.button).help("Bold")
                Toggle(isOn: binding(\.isItalic)) { Image(systemName: "italic") }
                    .toggleStyle(.button).help("Italic")
                Picker("Alignment", selection: binding(\.alignment)) {
                    Image(systemName: "text.alignleft").tag(TextBoxAlignment.leading)
                    Image(systemName: "text.aligncenter").tag(TextBoxAlignment.center)
                    Image(systemName: "text.alignright").tag(TextBoxAlignment.trailing)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            LabeledContent("Spacing") {
                Slider(value: binding(\.tracking), in: -0.05...0.5)
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

    private static let otherFamilies: [String] = {
        let favorites = Set(favoriteFamilies)
        return NSFontManager.shared.availableFontFamilies.filter { !favorites.contains($0) && !$0.hasPrefix(".") }
    }()

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
