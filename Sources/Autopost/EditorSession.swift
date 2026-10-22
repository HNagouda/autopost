import AutopostCore
import Foundation
import Observation

/// Which photo is open in the editor, which of its text boxes is selected, and the crop being drawn.
@MainActor @Observable
final class EditorSession {
    private static let filmstripKey = "isFilmstripShown"

    var photoID: Photo.ID?
    var selectedTextBoxID: TextBox.ID?
    var isShowingGrid = false
    // Set to ask the inspector to put the cursor in the selected box's text; the inspector clears it.
    var wantsTextFocus = false
    // The crop while it is being drawn. It is only written to the photo when the user applies it.
    var cropDraft: CropRect?
    // The shape a crop keeps while its handles are dragged; free keeps none.
    var cropShape = CropShape.free
    var typedPosition = TypedPosition()
    // Remembered between launches, like Lightroom's filmstrip.
    var isFilmstripShown = UserDefaults.standard.object(forKey: EditorSession.filmstripKey) as? Bool ?? true {
        didSet { UserDefaults.standard.set(isFilmstripShown, forKey: EditorSession.filmstripKey) }
    }

    var isOpen: Bool { photoID != nil }
    var isCropping: Bool { cropDraft != nil }

    func open(_ id: Photo.ID) {
        photoID = id
        selectedTextBoxID = nil
        cropDraft = nil
    }

    func close() {
        photoID = nil
        selectedTextBoxID = nil
        cropDraft = nil
    }

    // * ====================================================================
    // * === crop
    // * ====================================================================

    /// Opens the photo in the editor, if it is not already, and starts cropping it.
    func crop(_ photoID: Photo.ID, in store: LibraryStore, postID: Post.ID) {
        guard let photo = store.photo(photoID, in: postID) else { return }
        if self.photoID != photoID { open(photoID) }
        selectedTextBoxID = nil
        // A shape picked for the last photo would snap this one's crop on the first drag, so each starts free.
        cropShape = .free
        cropDraft = photo.crop
    }

    func applyCrop(in store: LibraryStore, postID: Post.ID) {
        guard let photoID, let cropDraft else { return }
        store.asOneUndoStep { store.updatePhoto(photoID, in: postID) { $0.crop = cropDraft } }
        self.cropDraft = nil
    }

    func cancelCrop() {
        cropDraft = nil
    }

    /// Switches the kept shape and, for a fixed one, redraws the crop at that shape. `imageAspect` is the photo's width over height.
    func useCropShape(_ shape: CropShape, imageAspect: Double) {
        cropShape = shape
        guard let draft = cropDraft, let ratio = shape.ratio(imageAspect: imageAspect) else { return }
        cropDraft = draft.fitted(toShape: ratio, imageAspect: imageAspect)
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

    /// Delete in the editor: the selected text box, or else the open photo, which moves the editor on to its neighbour.
    func deleteSelection(in store: LibraryStore, postID: Post.ID) {
        if selectedTextBoxID != nil {
            deleteSelectedBox(in: store, postID: postID)
            return
        }
        guard let photoID, let photos = store.post(postID)?.photos, let index = photos.firstIndex(where: { $0.id == photoID }) else { return }

        let neighbour = photos.indices.contains(index + 1) ? photos[index + 1] : index > 0 ? photos[index - 1] : nil
        if let neighbour { open(neighbour.id) } else { close() }
        store.removePhotos([photoID], from: postID)
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
