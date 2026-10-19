import AppKit
import AutopostCore
import SwiftUI

/// One photo, large, with its text boxes to place and a filmstrip of the rest of the post.
struct PhotoEditorView: View {
    let postID: Post.ID

    // Arrow keys move a selected box this far, as a fraction of the canvas; with Shift, ten times as far.
    private static let nudgeStep = 0.002
    private static let canvasPadding = 40.0

    @Environment(LibraryStore.self) private var store
    @Environment(EditorSession.self) private var editor
    @Environment(ThumbnailStore.self) private var thumbnails
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system
    @FocusState private var isCanvasFocused: Bool

    var body: some View {
        let post = store.post(postID)
        let photo = editor.photoID.flatMap { store.photo($0, in: postID) }

        VStack(spacing: 0) {
            if let post, let photo {
                canvas(photo: photo, post: post)
                Divider()
                Filmstrip(post: post)
            }
        }
        .background(theme.canvasBackground)
        .focusable()
        .focusEffectDisabled()
        .focused($isCanvasFocused)
        .onAppear { isCanvasFocused = true }
        .onExitCommand { editor.close() }
        .onDeleteCommand { deleteSelectedBox() }
        .onCopyCommand { copySelectedBox() }
        .onPasteCommand(of: [.plainText]) { _ in paste() }
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
            arrowKey(press.key, isShifted: press.modifiers.contains(.shift))
        }
        .onChange(of: store.post(postID)?.photos.map(\.id)) {
            // The open photo was removed or moved to another post.
            if let id = editor.photoID, store.photo(id, in: postID) == nil { editor.close() }
        }
    }

    private func canvas(photo: Photo, post: Post) -> some View {
        GeometryReader { geometry in
            let frame = post.frame(for: photo)
            let thumbnail = thumbnails.thumbnail(for: photo.url, isLarge: true)
            let ratio = FramedPhotoView.canvasRatio(thumbnail, frame: frame)
            let available = CGSize(
                width: geometry.size.width - 2 * Self.canvasPadding,
                height: geometry.size.height - 2 * Self.canvasPadding
            )
            let width = max(min(available.width, available.height * ratio), 1)
            let layout = FramedPhotoView.layout(frame: frame, thumbnail: thumbnail, width: width)

            FramedPhotoView(photo: photo, frame: post.frame, isLarge: true)
                .frame(width: width, height: width / ratio)
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                .overlay {
                    TextBoxOverlay(postID: postID, photo: photo, layout: layout, onInteract: { isCanvasFocused = true })
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .onTapGesture {
                    editor.select(nil)
                    isCanvasFocused = true
                }
                .contextMenu { canvasMenu(photo: photo) }
        }
    }

    @ViewBuilder
    private func canvasMenu(photo: Photo) -> some View {
        Button("Add Text Box") { editor.addTextBox(in: store, postID: postID) }
        Button("Paste") { paste() }
        Divider()
        Toggle("Show Grid", isOn: Binding(get: { editor.isShowingGrid }, set: { editor.isShowingGrid = $0 }))
    }

    // * ====================================================================
    // * === actions
    // * ====================================================================

    private func selectedBox() -> TextBox? {
        guard let photoID = editor.photoID, let boxID = editor.selectedTextBoxID else { return nil }
        return store.photo(photoID, in: postID)?.textBoxes.first { $0.id == boxID }
    }

    private func deleteSelectedBox() {
        guard let photoID = editor.photoID, let boxID = editor.selectedTextBoxID else { return }
        store.deleteTextBox(boxID, on: photoID, in: postID)
        editor.select(nil)
    }

    private func copySelectedBox() -> [NSItemProvider] {
        if let box = selectedBox() { store.copyTextBoxToPasteboard(box) }
        // The pasteboard is already written; returning nothing keeps SwiftUI from replacing it.
        return []
    }

    private func paste() {
        guard let photoID = editor.photoID else { return }
        if let id = store.pasteTextBox(onto: photoID, in: postID) { editor.select(id) }
    }

    /// Nudges the selected box, or steps through the post when nothing is selected.
    private func arrowKey(_ key: KeyEquivalent, isShifted: Bool) -> KeyPress.Result {
        guard let photoID = editor.photoID, let post = store.post(postID) else { return .ignored }

        if var box = selectedBox() {
            let step = Self.nudgeStep * (isShifted ? 10 : 1)
            switch key {
            case .leftArrow: box.x -= step
            case .rightArrow: box.x += step
            case .upArrow: box.y -= step
            default: box.y += step
            }
            store.updateTextBox(box, on: photoID, in: postID)
            return .handled
        }

        guard key == .leftArrow || key == .rightArrow, let index = post.photos.firstIndex(where: { $0.id == photoID }) else {
            return .ignored
        }
        let next = key == .leftArrow ? index - 1 : index + 1
        if post.photos.indices.contains(next) { editor.open(post.photos[next].id) }
        return .handled
    }
}

private struct Filmstrip: View {
    let post: Post

    // Tall enough to recognise a photo, short enough to leave the canvas most of the window.
    private static let height = 84.0

    @Environment(EditorSession.self) private var editor

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(post.photos) { photo in
                        FramedPhotoView(photo: photo, frame: post.frame)
                            .frame(height: Self.height - 24)
                            .overlay {
                                Rectangle().strokeBorder(Color.accentColor, lineWidth: editor.photoID == photo.id ? 2.5 : 0)
                            }
                            .opacity(editor.photoID == photo.id ? 1 : 0.7)
                            .id(photo.id)
                            .onTapGesture { editor.open(photo.id) }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: Self.height)
            .onChange(of: editor.photoID) {
                withAnimation { proxy.scrollTo(editor.photoID, anchor: .center) }
            }
        }
    }
}
