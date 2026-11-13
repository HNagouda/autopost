import AutopostCore
import Foundation

/// Stacking photos onto one slide, and spreading one photo across several slides.
extension LibraryStore {
    /// True when these entries can become one stack: at least two of them, holding two or three photos in all, none
    /// a canvas. A stack counts, so photos can be added to it, and so does a photo split across slides.
    func canStack(_ ids: Set<Photo.ID>, in postID: Post.ID) -> Bool {
        let photos = post(postID)?.photos.filter { ids.contains($0.id) } ?? []
        let imageCount = photos.reduce(0) { $0 + $1.images.count }
        return photos.count >= 2 && imageCount <= Photo.maxStackSize && photos.allSatisfy { !$0.isCanvas }
    }

    /// Stacks the selection when it can be stacked, or else lets the user click the photos to stack, keeping a
    /// selected photo or stack with room left as the first pick.
    func startStacking(in postID: Post.ID) {
        if canStack(selectedPhotoIDs, in: postID) {
            stackPhotos(selectedPhotoIDs, in: postID)
            return
        }
        let photos = post(postID)?.photos.filter { selectedPhotoIDs.contains($0.id) } ?? []
        let isStackable = photos.count == 1 && !photos[0].isCanvas && photos[0].images.count < Photo.maxStackSize
        selectedPhotoIDs = isStackable ? selectedPhotoIDs : []
        pickingLayout = .stack
    }

    /// Puts the photos on one slide in carousel order, at the place of the first entry, which keeps its text and
    /// border. A stack among them gives its photos to the new stack.
    func stackPhotos(_ ids: Set<Photo.ID>, in postID: Post.ID) {
        guard canStack(ids, in: postID), let photos = post(postID)?.photos.filter({ ids.contains($0.id) }) else { return }
        let base = photos[0]
        // A stack is one slide, so a photo that was split across slides stops being split.
        let added = photos.dropFirst().flatMap(\.images).map { image in
            var single = image
            single.stacked = []
            single.slideCount = 1
            return single
        }

        asOneUndoStep {
            update(postID) { post in
                post.photos.removeAll { ids.contains($0.id) && $0.id != base.id }
                guard let index = post.photos.firstIndex(where: { $0.id == base.id }) else { return }
                post.photos[index].slideCount = 1
                post.photos[index].stacked = base.stacked + added
            }
        }
        selectedPhotoIDs = [base.id]
        pickingLayout = nil
        toast = Toast(message: "Stacked \(Self.photoCount(base.images.count + added.count)) on one slide", systemImage: "square.stack", undoDepth: undoDepth)
    }

    /// Takes one photo out of the stack and puts it back in the post, right after the stack. A stack of two is
    /// left as a single photo.
    func removeStackedPhoto(_ index: Int, of id: Photo.ID, in postID: Post.ID) {
        var removed: Photo?
        asOneUndoStep {
            update(postID) { post in
                guard let place = post.photos.firstIndex(where: { $0.id == id }), post.photos[place].isStack else { return }
                removed = post.photos[place].removeImage(at: index)
                if let removed { post.photos.insert(removed, at: place + 1) }
            }
        }
        guard let removed else { return }
        toast = Toast(message: "Took \(removed.url.lastPathComponent) out of the stack", systemImage: "square.stack", undoDepth: undoDepth)
    }

    /// Gives the stacked photos back their own slides, right after the top one, as they were before stacking.
    func unstackPhoto(_ id: Photo.ID, in postID: Post.ID) {
        guard let photo = photo(id, in: postID), photo.isStack else { return }

        asOneUndoStep {
            update(postID) { post in
                guard let index = post.photos.firstIndex(where: { $0.id == id }) else { return }
                post.photos[index].stacked = []
                post.photos.insert(contentsOf: photo.stacked, at: index + 1)
            }
        }
        selectedPhotoIDs = Set(photo.images.map(\.id))
        toast = Toast(message: "Unstacked \(Self.photoCount(photo.images.count))", systemImage: "square.stack", undoDepth: undoDepth)
    }

    /// Exchanges two photos of a stack, counted from the top.
    func swapStackedPhotos(_ first: Int, _ second: Int, of id: Photo.ID, in postID: Post.ID) {
        asOneUndoStep { updatePhoto(id, in: postID) { $0.swapImages(first, second) } }
    }

    /// Spreads a photo across `count` slides, or back onto one. A stack always stays on one slide.
    func setSlideCount(_ count: Int, of id: Photo.ID, in postID: Post.ID) {
        guard let photo = photo(id, in: postID), !photo.isStack, !photo.isCanvas else { return }
        let clamped = min(max(count, 1), Photo.maxSlideCount)
        asOneUndoStep { updatePhoto(id, in: postID) { $0.slideCount = clamped } }
    }

    /// Crops for the photos of a stack or canvas, keyed by place in `images`: 0 is the first photo itself.
    /// A single photo only has place 0. All of them are one undo step.
    func setCrops(_ crops: [Int: CropRect], in id: Photo.ID, postID: Post.ID) {
        asOneUndoStep {
            updatePhoto(id, in: postID) { photo in
                for (index, crop) in crops {
                    if index == 0 {
                        photo.crop = crop
                    } else if photo.stacked.indices.contains(index - 1) {
                        photo.stacked[index - 1].crop = crop
                    }
                }
            }
        }
    }
}
