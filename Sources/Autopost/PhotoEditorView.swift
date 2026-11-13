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
    @State private var keyMonitor: Any?

    var body: some View {
        let post = store.post(postID)
        let photo = editor.photoID.flatMap { store.photo($0, in: postID) }

        VStack(spacing: 0) {
            if let post, let photo {
                if editor.isCropping {
                    CropView(postID: postID, photo: photo)
                } else {
                    canvas(photo: photo, post: post)
                }
                FilmstripToggle()
                if editor.isFilmstripShown {
                    Filmstrip(post: post)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: editor.isFilmstripShown)
        .background(theme.canvasBackground)
        .onAppear { startKeyMonitor() }
        .onDisappear { stopKeyMonitor() }
        .onChange(of: openImages) { old, new in
            // The same entry with more or fewer photos, after an unstack, a break apart or an undo. A photo picked or
            // a crop begun before may point at another photo now.
            guard old.photoID == new.photoID, old.count != new.count else { return }
            editor.selectedImageIndex = nil
            editor.cancelCrop()
        }
        .onChange(of: store.post(postID)?.photos.map(\.id)) {
            // The open photo was removed or moved to another post.
            if let id = editor.photoID, store.photo(id, in: postID) == nil { editor.close() }
        }
    }

    private struct OpenImages: Equatable {
        var photoID: Photo.ID?
        var count: Int
    }

    private var openImages: OpenImages {
        OpenImages(photoID: editor.photoID, count: editor.photoID.flatMap { store.photo($0, in: postID) }?.images.count ?? 0)
    }

    private func canvas(photo: Photo, post: Post) -> some View {
        GeometryReader { geometry in
            let frame = post.frame(for: photo)
            let loaded = FramedPhotoView.loadedThumbnails(for: photo, in: thumbnails, isLarge: true)
            let cameraNames = store.cameraNames
            let ratio = FramedPhotoView.canvasRatio(photo: photo, frame: frame, thumbnails: loaded, cameraNames: cameraNames)
            let available = CGSize(
                width: geometry.size.width - 2 * Self.canvasPadding,
                height: geometry.size.height - 2 * Self.canvasPadding
            )
            // A canvas of many slides fitted to the window would be a thin strip, too small to place photos on. It
            // keeps the full height instead and scrolls sideways.
            let isScrolling = photo.isCanvas && available.height * ratio > available.width
            let width = isScrolling ? max(available.height * ratio, 1) : max(min(available.width, available.height * ratio), 1)
            let layout = FramedPhotoView.layout(
                photo: photo, frame: frame, thumbnails: loaded, cameraNames: cameraNames, slideWidth: width / Double(photo.slideCount)
            )
            let framed = FramedPhotoView(photo: photo, frame: post.frame, isLarge: true, showsSeams: true)
                .frame(width: width, height: width / ratio)
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                .overlay {
                    if photo.isCanvas {
                        CanvasBoxOverlay(postID: postID, photo: photo, layout: layout, onInteract: focusCanvas)
                    } else if photo.isStack {
                        StackOverlay(postID: postID, photo: photo, layout: layout)
                    }
                }
                .overlay {
                    TextBoxOverlay(postID: postID, photo: photo, layout: layout, onInteract: focusCanvas)
                }

            Group {
                if isScrolling {
                    ScrollView(.horizontal) {
                        framed
                            .padding(.horizontal, Self.canvasPadding)
                            .frame(height: geometry.size.height)
                    }
                } else {
                    framed.frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
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
        if !photo.isCanvas {
            Button("Crop Photo") { editor.crop(photo.id, in: store, postID: postID) }
        }
        Divider()
        Toggle("Show Grid", isOn: Binding(get: { editor.isShowingGrid }, set: { editor.isShowingGrid = $0 }))
    }

    /// Takes the cursor out of any inspector text field, so the keyboard acts on text boxes again.
    private func focusCanvas() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    // * ====================================================================
    // * === keyboard
    // * ====================================================================

    /// Watches key presses in the editor window directly. SwiftUI's key handlers only fire while the canvas
    /// holds focus, and clicking a text box does not reliably give it focus.
    private func startKeyMonitor() {
        let store = store
        let editor = editor
        let postID = postID
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard WindowID.isMain(event.window) else { return event }
            return Self.handleKey(event, store: store, editor: editor, postID: postID) ? nil : event
        }
    }

    private func stopKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// True when the key was used. Typing in a text field and shortcuts with ⌘, ⌥ or ⌃ pass through untouched.
    private static func handleKey(_ event: NSEvent, store: LibraryStore, editor: EditorSession, postID: Post.ID) -> Bool {
        guard KeyCode.hasNoShortcutModifiers(event), !KeyCode.isTyping(in: event.window) else { return false }
        if event.charactersIgnoringModifiers == "/" {
            editor.isFilmstripShown.toggle()
            return true
        }
        if editor.isCropping { return cropKey(event, store: store, editor: editor, postID: postID) }

        if KeyCode.isDelete(event.keyCode) {
            // A plain Delete removes a selected text box, or takes the selected photo of a canvas or stack out of it
            // and back into the post. Removing the open entry itself takes ⌘⌫, so a stray key press can't, and a held
            // key never repeats a delete.
            guard editor.selectedTextBoxID != nil || editor.selectedImageIndex != nil, !event.isARepeat else { return false }
            editor.deleteSelection(in: store, postID: postID)
            return true
        }
        if KeyCode.isArrow(event.keyCode) {
            return arrowKey(event.keyCode, isShifted: event.modifierFlags.contains(.shift), store: store, editor: editor, postID: postID)
        }
        if event.keyCode == KeyCode.escape {
            // A held Escape would clear the selection and then close the editor too.
            guard !event.isARepeat else { return true }
            if editor.selectedTextBoxID != nil || editor.selectedImageIndex != nil { editor.select(nil) } else { editor.close() }
            return true
        }

        if let digit = KeyCode.digit(event.keyCode) {
            guard let photoID = editor.photoID, let count = store.post(postID)?.photos.count,
                  let position = editor.typedPosition.type(digit, photoCount: count)
            else { return false }
            store.movePhoto(photoID, in: postID, toPosition: position)
            return true
        }

        switch event.charactersIgnoringModifiers {
        case "c":
            // A held C would start the crop and then apply it straight away.
            guard !event.isARepeat else { return true }
            guard let photoID = editor.photoID, let photo = store.photo(photoID, in: postID) else { return false }
            // On a canvas C crops the selected photo; with none selected there is nothing to crop.
            if photo.isCanvas, editor.selectedImageIndex == nil { return false }
            editor.crop(photoID, in: store, postID: postID, imageIndex: editor.selectedImageIndex ?? 0)
            return true
        default:
            return false
        }
    }

    /// While cropping, Return or C applies, Escape cancels, and other editor keys are held back.
    private static func cropKey(_ event: NSEvent, store: LibraryStore, editor: EditorSession, postID: Post.ID) -> Bool {
        switch event.keyCode {
        case KeyCode.returnKey, KeyCode.keypadEnter:
            editor.applyCrop(in: store, postID: postID)
            return true
        case KeyCode.escape:
            editor.cancelCrop()
            return true
        default:
            break
        }

        if event.charactersIgnoringModifiers == "c" {
            guard !event.isARepeat else { return true }
            editor.applyCrop(in: store, postID: postID)
            return true
        }
        return KeyCode.isDelete(event.keyCode) || KeyCode.isArrow(event.keyCode)
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
        // A grid sets every photo's place, so the arrows have nothing to nudge there.
        if let index = editor.selectedImageIndex, let photo = post.photos.first(where: { $0.id == photoID }), photo.boxes.indices.contains(index),
           photo.gridSpacing == nil {
            var box = photo.boxes[index]
            let step = nudgeStep * (isShifted ? 10 : 1)
            switch keyCode {
            case KeyCode.left: box.x -= step
            case KeyCode.right: box.x += step
            case KeyCode.up: box.y -= step
            default: box.y += step
            }
            store.setCanvasBox(box, at: index, of: photoID, in: postID)
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

/// The thin bar above the filmstrip with a chevron that hides or shows it, like a folder's disclosure arrow in Finder.
private struct FilmstripToggle: View {
    @Environment(EditorSession.self) private var editor

    var body: some View {
        HStack {
            Spacer()
            Button {
                editor.isFilmstripShown.toggle()
            } label: {
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(editor.isFilmstripShown ? 0 : 180))
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 28, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(editor.isFilmstripShown ? "Hide the filmstrip (/)" : "Show the filmstrip (/)")
            .accessibilityLabel(editor.isFilmstripShown ? "Hide filmstrip" : "Show filmstrip")
        }
        .padding(.horizontal, 12)
        .frame(height: 22)
        .overlay(alignment: .top) { Divider() }
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
                        FramedPhotoView(photo: photo, frame: post.frame, showsSeams: true)
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
                // The open photo slides to its new place when the number keys move it.
                .animation(PostGridView.reorderAnimation, value: post.photos.map(\.id))
            }
            .frame(height: Self.height)
            .onChange(of: editor.photoID) {
                withAnimation { proxy.scrollTo(editor.photoID, anchor: .center) }
            }
        }
    }
}
