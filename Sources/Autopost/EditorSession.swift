import AutopostCore
import Observation

/// Which photo is open in the editor and which of its text boxes is selected.
@MainActor @Observable
final class EditorSession {
    var photoID: Photo.ID?
    var selectedTextBoxID: TextBox.ID?
    var isShowingGrid = false
    // Bumped to ask the inspector to put the cursor in the selected box's text.
    var textFocusRequest = 0

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

    func select(_ boxID: TextBox.ID?, focusingText: Bool = false) {
        selectedTextBoxID = boxID
        if focusingText { textFocusRequest += 1 }
    }
}
