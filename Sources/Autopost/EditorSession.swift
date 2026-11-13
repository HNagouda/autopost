import AutopostCore
import Foundation
import Observation

/// Which photo is open in the editor, which of its text boxes is selected, and the crop being drawn.
@MainActor @Observable
final class EditorSession {
    private static let filmstripKey = "isFilmstripShown"

    var photoID: Photo.ID?
    var selectedTextBoxID: TextBox.ID?
    // Which photo of the open canvas or stack is selected, by its place in `images`.
    var selectedImageIndex: Int?
    var isShowingGrid = false
    // Set to ask the inspector to put the cursor in the selected box's text; the inspector clears it.
    var wantsTextFocus = false
    // The crop while it is being drawn. It is only written to the photo when the user applies it.
    var cropDraft: CropRect?
    // The shape a crop keeps while its handles are dragged; free keeps none.
    var cropShape = CropShape.free
    // Which photo of a stack or canvas is being cropped, by its place in `images`: 0 is the top one of a stack.
    var cropImageIndex = 0
    // Crops drawn for the other photos of a stack or canvas during this crop, written together when it is applied.
    private var pendingCrops: [Int: CropRect] = [:]
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
        selectedImageIndex = nil
        cancelCrop()
    }

    func close() {
        photoID = nil
        selectedTextBoxID = nil
        selectedImageIndex = nil
        cancelCrop()
    }

    // * ====================================================================
    // * === crop
    // * ====================================================================

    /// Opens the photo in the editor, if it is not already, and starts cropping it. `imageIndex` picks one photo
    /// of a stack or a canvas.
    func crop(_ photoID: Photo.ID, in store: LibraryStore, postID: Post.ID, imageIndex: Int = 0) {
        guard let photo = store.photo(photoID, in: postID), photo.images.indices.contains(imageIndex) else { return }
        if self.photoID != photoID { open(photoID) }
        selectedTextBoxID = nil
        // A shape picked for the last photo would snap this one's crop on the first drag, so each starts free.
        cropShape = .free
        cropImageIndex = imageIndex
        pendingCrops = [:]
        cropDraft = photo.images[imageIndex].crop
    }

    /// Switches the crop to another photo of the open stack, keeping what was drawn for the last one until the
    /// crop is applied or cancelled.
    func cropImage(_ index: Int, in store: LibraryStore, postID: Post.ID) {
        guard let photoID, let photo = store.photo(photoID, in: postID), photo.images.indices.contains(index) else { return }
        pendingCrops[cropImageIndex] = cropDraft
        cropImageIndex = index
        cropDraft = pendingCrops[index] ?? photo.images[index].crop
    }

    func applyCrop(in store: LibraryStore, postID: Post.ID) {
        guard let photoID, let cropDraft else { return }
        pendingCrops[cropImageIndex] = cropDraft
        store.setCrops(pendingCrops, in: photoID, postID: postID)
        pendingCrops = [:]
        self.cropDraft = nil
    }

    func cancelCrop() {
        pendingCrops = [:]
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
        select(store.addTextBox(to: photoID, in: postID, overCanvasImage: selectedImageIndex), focusingText: true)
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

    /// Delete in the editor: the selected text box, the selected photo of a canvas or stack, or else the open photo, which
    /// moves the editor on to its neighbour.
    func deleteSelection(in store: LibraryStore, postID: Post.ID) {
        if selectedTextBoxID != nil {
            deleteSelectedBox(in: store, postID: postID)
            return
        }
        if let photoID, let index = selectedImageIndex {
            if store.photo(photoID, in: postID)?.isStack == true {
                store.removeStackedPhoto(index, of: photoID, in: postID)
            } else {
                store.removeCanvasImage(index, of: photoID, in: postID)
            }
            selectedImageIndex = nil
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

    /// Selects a text box, or nothing. Either way no photo of a canvas or stack stays selected.
    func select(_ boxID: TextBox.ID?, focusingText: Bool = false) {
        selectedTextBoxID = boxID
        selectedImageIndex = nil
        wantsTextFocus = focusingText
    }

    func selectImage(_ index: Int) {
        selectedTextBoxID = nil
        selectedImageIndex = index
    }
}
