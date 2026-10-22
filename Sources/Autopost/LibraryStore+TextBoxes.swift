import AppKit
import AutopostCore
import Foundation

/// Per-photo changes: the photo's own border and position, its camera settings, and its text boxes.
extension LibraryStore {
    // Pasteboard type for a copied text box. Plain text goes alongside, so pasting into other apps gives the words.
    static let textBoxPasteboardType = NSPasteboard.PasteboardType("\(AppIdentity.bundleID).textbox")

    func photo(_ photoID: Photo.ID, in postID: Post.ID) -> Photo? {
        post(postID)?.photos.first { $0.id == photoID }
    }

    func updatePhoto(_ photoID: Photo.ID, in postID: Post.ID, _ change: (inout Photo) -> Void) {
        update(postID) { post in
            guard let index = post.photos.firstIndex(where: { $0.id == photoID }) else { return }
            change(&post.photos[index])
        }
    }

    /// Gives every photo in the post the camera settings typed for this one, for a film roll shot on one camera.
    func copyCameraSettingsToAllPhotos(from photoID: Photo.ID, in postID: Post.ID) {
        guard let settings = photo(photoID, in: postID)?.cameraOverrides else { return }
        update(postID) { post in
            for index in post.photos.indices { post.photos[index].cameraOverrides = settings }
        }
        toast = Toast(message: "Camera settings copied to every photo", systemImage: "camera")
    }

    /// A new box copies the last one placed, so repeated text lands in the same spot on the next photo.
    @discardableResult
    func addTextBox(to photoID: Photo.ID, in postID: Post.ID, text: String? = nil) -> TextBox.ID? {
        guard let post = post(postID) else { return nil }
        var box = library.textBoxTemplate?.duplicated() ?? Self.firstTextBox(on: post.frame)
        if let text { box.text = text }

        updatePhoto(photoID, in: postID) { $0.textBoxes.append(box) }
        library.textBoxTemplate = box
        return box.id
    }

    /// Writes the change and remembers the box as the template for the next new one.
    func updateTextBox(_ box: TextBox, on photoID: Photo.ID, in postID: Post.ID) {
        updatePhoto(photoID, in: postID) { photo in
            guard let index = photo.textBoxes.firstIndex(where: { $0.id == box.id }) else { return }
            photo.textBoxes[index] = box
        }
        library.textBoxTemplate = box
    }

    func deleteTextBox(_ boxID: TextBox.ID, on photoID: Photo.ID, in postID: Post.ID) {
        updatePhoto(photoID, in: postID) { $0.textBoxes.removeAll { $0.id == boxID } }
    }

    /// Adds a copy of the box, in the same place, to every other photo in the post.
    func copyTextBoxToAllPhotos(_ box: TextBox, from photoID: Photo.ID, in postID: Post.ID) {
        update(postID) { post in
            for index in post.photos.indices where post.photos[index].id != photoID {
                post.photos[index].textBoxes.append(box.duplicated())
            }
        }
    }

    func copyTextBoxToPasteboard(_ box: TextBox) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(box.text, forType: .string)
        if let data = try? JSONEncoder().encode(box) {
            pasteboard.setData(data, forType: Self.textBoxPasteboardType)
        }
    }

    /// Pastes a copied box where it was, or turns plain text from elsewhere into a new box at the template's spot.
    @discardableResult
    func pasteTextBox(onto photoID: Photo.ID, in postID: Post.ID) -> TextBox.ID? {
        let pasteboard = NSPasteboard.general
        if let data = pasteboard.data(forType: Self.textBoxPasteboardType),
           let copied = try? JSONDecoder().decode(TextBox.self, from: data) {
            let box = copied.duplicated()
            updatePhoto(photoID, in: postID) { $0.textBoxes.append(box) }
            library.textBoxTemplate = box
            return box.id
        }
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return addTextBox(to: photoID, in: postID, text: text)
        }
        return nil
    }

    /// Dark text on a light frame, light text on a dark one.
    private static func firstTextBox(on frame: FrameSettings) -> TextBox {
        var box = TextBox()
        let isLight = frame.background == .color && frame.color.isLight
        box.color = isLight ? FrameColor(red: 0.2, green: 0.2, blue: 0.2) : FrameColor(red: 0.95, green: 0.95, blue: 0.95)
        return box
    }
}
