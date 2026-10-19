import AutopostCore
import Observation

/// Which photo is open in the editor and which of its text boxes is selected.
@MainActor @Observable
final class EditorSession {
    var photoID: Photo.ID?
    var selectedTextBoxID: TextBox.ID?
    var isShowingGrid = false
    // Set to ask the inspector to put the cursor in the selected box's text; the inspector clears it.
    var wantsTextFocus = false

    var isOpen: Bool { photoID != nil }

    func open(_ id: Photo.ID) {
        photoID = id
        selectedTextBoxID = nil
    }

    func close() {
        photoID = nil
        selectedTextBoxID = nil
    }

    func addTextBox(in store: LibraryStore, postID: Post.ID) {
        guard let photoID else { return }
        select(store.addTextBox(to: photoID, in: postID), focusingText: true)
    }

    func selectedBox(in store: LibraryStore, postID: Post.ID) -> TextBox? {
        guard let photoID, let selectedTextBoxID else { return nil }
        return store.photo(photoID, in: postID)?.textBoxes.first { $0.id == selectedTextBoxID }
    }

    /// False when there was no selected box to copy.
    @discardableResult
    func copySelectedBox(in store: LibraryStore, postID: Post.ID) -> Bool {
        guard let box = selectedBox(in: store, postID: postID) else { return false }
        store.copyTextBoxToPasteboard(box)
        return true
    }

    func deleteSelectedBox(in store: LibraryStore, postID: Post.ID) {
        guard let photoID, let selectedTextBoxID else { return }
        store.deleteTextBox(selectedTextBoxID, on: photoID, in: postID)
        select(nil)
    }

    func paste(in store: LibraryStore, postID: Post.ID) {
        guard let photoID else { return }
        if let id = store.pasteTextBox(onto: photoID, in: postID) { select(id) }
    }

    func select(_ boxID: TextBox.ID?, focusingText: Bool = false) {
        selectedTextBoxID = boxID
        wantsTextFocus = focusingText
    }
}
