import AutopostCore
import Foundation

/// Adding, moving, reordering and removing the photos of a post.
extension LibraryStore {
    /// "1 photo", "3 photos".
    static func photoCount(_ count: Int) -> String {
        count == 1 ? "1 photo" : "\(count) photos"
    }

    func addPhotos(_ urls: [URL], to id: Post.ID, before target: Photo.ID? = nil) {
        let photos = FileImport.photoURLs(in: urls).map { Photo(url: $0) }
        guard !photos.isEmpty, let post = post(id) else { return }
        asOneUndoStep {
            update(id) { post in
                let index = target.flatMap { target in post.photos.firstIndex { $0.id == target } } ?? post.photos.endIndex
                post.photos.insert(contentsOf: photos, at: index)
            }
        }
        toast = Toast(message: "Added \(Self.photoCount(photos.count)) to “\(post.name)”", systemImage: "photo.badge.plus")
    }

    func addPhotosToSelectedPost(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        if let id = selectedPostID {
            addPhotos(urls, to: id)
        } else {
            createPost(photos: FileImport.photoURLs(in: urls))
        }
    }

    /// Splits a drop on `post` into its own photos to move and new files to add. Dragging one selected photo
    /// carries the whole selection.
    func splitDrop(_ urls: [URL], on post: Post) -> (moving: Set<Photo.ID>, newFiles: [URL]) {
        let dragged = Set(post.photos.filter { urls.contains($0.url) }.map(\.id))
        // An empty drag is a subset of any selection, so files from Finder must not pick up the selected photos.
        let carriesSelection = !dragged.isEmpty && dragged.isSubset(of: selectedPhotoIDs)
        let newFiles = urls.filter { url in !post.photos.contains { $0.url == url } }
        return (carriesSelection ? selectedPhotoIDs : dragged, newFiles)
    }

    /// Moves photos to another place in the same post, keeping their order, in front of `target` or to the end.
    func reorderPhotos(_ ids: Set<Photo.ID>, in postID: Post.ID, before target: Photo.ID?) {
        if let target, ids.contains(target) { return }
        asOneUndoStep {
            update(postID) { post in
                let moving = post.photos.filter { ids.contains($0.id) }
                post.photos.removeAll { ids.contains($0.id) }
                let index = target.flatMap { target in post.photos.firstIndex { $0.id == target } } ?? post.photos.endIndex
                post.photos.insert(contentsOf: moving, at: index)
            }
        }
    }

    /// Puts a photo at a carousel position counted from 1, the way the number keys do.
    func movePhoto(_ photoID: Photo.ID, in postID: Post.ID, toPosition position: Int) {
        guard let count = post(postID)?.photos.count else { return }
        let clamped = min(max(position, 1), count)
        asOneUndoStep {
            update(postID) { post in
                guard let index = post.photos.firstIndex(where: { $0.id == photoID }) else { return }
                let photo = post.photos.remove(at: index)
                post.photos.insert(photo, at: clamped - 1)
            }
        }
    }

    /// Moves photos to the end of another post, in their order.
    func movePhotos(_ ids: Set<Photo.ID>, from source: Post.ID, to destination: Post.ID) {
        guard source != destination, let from = post(source), let to = post(destination) else { return }
        let moved = from.photos.filter { ids.contains($0.id) }
        guard !moved.isEmpty else { return }

        asOneUndoStep {
            update(source) { $0.photos.removeAll { ids.contains($0.id) } }
            update(destination) { $0.photos.append(contentsOf: moved) }
        }
        selectedPhotoIDs.subtract(ids)
        toast = Toast(message: "Moved \(Self.photoCount(moved.count)) to “\(to.name)”", systemImage: "arrow.right.square", undoDepth: undoDepth)
    }

    /// Takes photos out of the post and out of the selection, with a toast to undo it.
    func removePhotos(_ ids: Set<Photo.ID>, from postID: Post.ID) {
        guard let post = post(postID) else { return }
        let removed = post.photos.filter { ids.contains($0.id) }
        guard !removed.isEmpty else { return }

        asOneUndoStep { update(postID) { $0.photos.removeAll { ids.contains($0.id) } } }
        selectedPhotoIDs.subtract(ids)
        toast = Toast(message: "Removed \(Self.photoCount(removed.count)) from “\(post.name)”", systemImage: "trash", undoDepth: undoDepth)
    }

    /// What Delete and ⌘⌫ remove outside the editor: the selected photos, or the selected post when no photo is
    /// selected or the sidebar has the keyboard. Both can be undone, and a post also waits in Recently Deleted.
    func deleteSelection(isSidebarFocused: Bool) {
        guard let postID = selectedPostID else { return }
        if !selectedPhotoIDs.isEmpty && !isSidebarFocused {
            removePhotos(selectedPhotoIDs, from: postID)
        } else {
            deletePost(postID)
        }
    }
}
