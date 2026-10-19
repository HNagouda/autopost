import AppKit
import AutopostCore
import SwiftUI

/// One photo, large, with its text boxes to place and a filmstrip of the rest of the post.
struct PhotoEditorView: View {
    let postID: Post.ID

    // Arrow keys move a selected box this far, as a fraction of the canvas; with Shift, ten times as far.
    private static let nudgeStep = 0.002
    private static let canvasPadding = 40.0

    // Hardware key codes, which stay the same on every keyboard layout.
    private enum KeyCode {
        static let delete: UInt16 = 51
        static let forwardDelete: UInt16 = 117
        static let escape: UInt16 = 53
        static let left: UInt16 = 123
        static let right: UInt16 = 124
        static let down: UInt16 = 125
        static let up: UInt16 = 126
    }

    @Environment(LibraryStore.self) private var store
    @Environment(EditorSession.self) private var editor
    @Environment(ThumbnailStore.self) private var thumbnails
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system
    @State private var keyMonitor: Any?

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
        .onAppear { startKeyMonitor() }
        .onDisappear { stopKeyMonitor() }
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
                    TextBoxOverlay(postID: postID, photo: photo, layout: layout, onInteract: focusCanvas)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .onTapGesture {
                    editor.select(nil)
                    focusCanvas()
                }
                .contextMenu { canvasMenu(photo: photo) }
        }
    }

    @ViewBuilder
    private func canvasMenu(photo: Photo) -> some View {
        Button("Add Text Box") { editor.addTextBox(in: store, postID: postID) }
        Button("Paste") { editor.paste(in: store, postID: postID) }
        Divider()
        Toggle("Show Grid", isOn: Binding(get: { editor.isShowingGrid }, set: { editor.isShowingGrid = $0 }))
    }

    /// Takes the cursor out of any inspector text field, so the keyboard acts on text boxes again.
    private func focusCanvas() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    // * ====================================================================
    // * === actions
    // * ====================================================================

    // * ====================================================================
    // * === keyboard
    // * ====================================================================

    /// Watches key presses in the editor window directly. SwiftUI's key handlers only fire while the canvas
    /// holds focus, and clicking a text box does not reliably give it focus.
    private func startKeyMonitor() {
        let window = NSApp.keyWindow
        let store = store
        let editor = editor
        let postID = postID
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.window === window else { return event }
            return Self.handleKey(event, store: store, editor: editor, postID: postID) ? nil : event
        }
    }

    private func stopKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// True when the key was used. Typing in a text field and shortcuts with ⌘, ⌥ or ⌃ pass through untouched.
    private static func handleKey(_ event: NSEvent, store: LibraryStore, editor: EditorSession, postID: Post.ID) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control])
        guard modifiers.isEmpty, !(event.window?.firstResponder is NSText) else { return false }

        switch event.keyCode {
        case KeyCode.delete, KeyCode.forwardDelete:
            guard editor.selectedTextBoxID != nil else { return false }
            editor.deleteSelectedBox(in: store, postID: postID)
            return true
        case KeyCode.escape:
            if editor.selectedTextBoxID != nil { editor.select(nil) } else { editor.close() }
            return true
        case KeyCode.left, KeyCode.right, KeyCode.up, KeyCode.down:
            return arrowKey(event.keyCode, isShifted: event.modifierFlags.contains(.shift), store: store, editor: editor, postID: postID)
        default:
            return false
        }
    }

    /// Nudges the selected box, or steps through the post when nothing is selected.
    private static func arrowKey(_ keyCode: UInt16, isShifted: Bool, store: LibraryStore, editor: EditorSession, postID: Post.ID) -> Bool {
        guard let photoID = editor.photoID, let post = store.post(postID) else { return false }

        if var box = editor.selectedBox(in: store, postID: postID) {
            let step = nudgeStep * (isShifted ? 10 : 1)
            switch keyCode {
            case KeyCode.left: box.x -= step
            case KeyCode.right: box.x += step
            case KeyCode.up: box.y -= step
            default: box.y += step
            }
            store.updateTextBox(box, on: photoID, in: postID)
            return true
        }

        guard keyCode == KeyCode.left || keyCode == KeyCode.right,
              let index = post.photos.firstIndex(where: { $0.id == photoID })
        else { return false }
        let next = keyCode == KeyCode.left ? index - 1 : index + 1
        if post.photos.indices.contains(next) { editor.open(post.photos[next].id) }
        return true
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
