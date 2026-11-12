import AppKit
import AutopostCore
import SwiftUI

/// Keys for the post grid: the arrows pick a photo, Delete removes, the number keys set a photo's position, C crops,
/// and ⇧- and ⇧+ zoom.
@MainActor
final class GridKeyboard {
    weak var window: NSWindow?
    private var monitor: Any?
    private var typedPosition = TypedPosition()

    func start(store: LibraryStore, editor: EditorSession) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            return self.handle(event, store: store, editor: editor) ? nil : event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    /// True when the key was used. Typing in a text field and shortcuts with ⌘, ⌥ or ⌃ pass through untouched.
    private func handle(_ event: NSEvent, store: LibraryStore, editor: EditorSession) -> Bool {
        guard KeyCode.hasNoShortcutModifiers(event), !KeyCode.isTyping(in: event.window), let post = store.selectedPost else { return false }
        let selected = post.photos.filter { store.selectedPhotoIDs.contains($0.id) }

        // A plain Delete only takes the whole post while the sidebar has the keyboard, so pressing it after
        // clicking a slider in the inspector never deletes a post. ⌘⌫ is the deliberate version. A held key
        // never repeats a delete.
        if KeyCode.isDelete(event.keyCode) {
            let isSidebarFocused = event.window?.firstResponder is NSTableView
            guard isSidebarFocused || !selected.isEmpty, !event.isARepeat else { return false }
            store.deleteSelection(isSidebarFocused: isSidebarFocused)
            return true
        }
        if let digit = KeyCode.digit(event.keyCode) {
            guard let photo = selected.first, selected.count == 1,
                  let position = typedPosition.type(digit, photoCount: post.photos.count)
            else { return false }
            store.movePhoto(photo.id, in: post.id, toPosition: position)
            return true
        }
        // In the sidebar the arrows belong to the post list.
        if event.keyCode == KeyCode.left || event.keyCode == KeyCode.right, !(event.window?.firstResponder is NSTableView) {
            return step(isForward: event.keyCode == KeyCode.right, in: post, store: store)
        }
        if event.keyCode == KeyCode.escape, store.pickingLayout != nil {
            store.pickingLayout = nil
            store.selectedPhotoIDs = []
            return true
        }
        if event.keyCode == KeyCode.escape, !selected.isEmpty {
            store.selectedPhotoIDs = []
            return true
        }

        switch event.charactersIgnoringModifiers {
        case "c":
            guard let photo = selected.first, selected.count == 1 else { return false }
            // A canvas has a crop per photo, picked in the editor, so C opens the canvas there.
            if photo.isCanvas { editor.open(photo.id) } else { editor.crop(photo.id, in: store, postID: post.id) }
            return true
        // Shift is required so a stray - or = never resizes the grid. With Shift held those keys type _ and +.
        case "_" where event.modifierFlags.contains(.shift):
            TileSize.zoom(by: -TileSize.step)
            return true
        case "+" where event.modifierFlags.contains(.shift):
            TileSize.zoom(by: TileSize.step)
            return true
        default:
            return false
        }
    }

    /// Selects the photo after the selection, or before it. From nothing, forward starts at the first photo and
    /// back at the last, so a whole carousel can be put in order from the keyboard.
    private func step(isForward: Bool, in post: Post, store: LibraryStore) -> Bool {
        guard !post.photos.isEmpty else { return false }
        let first = post.photos.firstIndex { store.selectedPhotoIDs.contains($0.id) }
        let last = post.photos.lastIndex { store.selectedPhotoIDs.contains($0.id) }
        let index = isForward
            ? last.map { min($0 + 1, post.photos.count - 1) } ?? 0
            : first.map { max($0 - 1, 0) } ?? post.photos.count - 1

        store.selectedPhotoIDs = [post.photos[index].id]
        return true
    }
}
