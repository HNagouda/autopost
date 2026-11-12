import AutopostCore
import Foundation

/// Stacking photos onto one slide, and spreading one photo across several slides.
extension LibraryStore {
    /// True when these photos can become one stack: two or three plain photos, none already stacked or spread.
    func canStack(_ ids: Set<Photo.ID>, in postID: Post.ID) -> Bool {
        let photos = post(postID)?.photos.filter { ids.contains($0.id) } ?? []
        return (2...Photo.maxStackSize).contains(photos.count) && photos.allSatisfy { !$0.isStack && $0.slideCount == 1 }
    }

    /// Stacks the selection when it can be stacked, or else lets the user click the photos to stack, keeping a
    /// selected photo that can go in a stack as the first pick.
    func startStacking(in postID: Post.ID) {
        if canStack(selectedPhotoIDs, in: postID) {
            stackPhotos(selectedPhotoIDs, in: postID)
            return
        }
        let photos = post(postID)?.photos.filter { selectedPhotoIDs.contains($0.id) } ?? []
        let isStackable = photos.count == 1 && !photos[0].isStack && photos[0].slideCount == 1
        selectedPhotoIDs = isStackable ? selectedPhotoIDs : []
        isPickingStack = true
    }

    /// Puts the photos on one slide in carousel order, at the place of the first one, which keeps its text and border.
    func stackPhotos(_ ids: Set<Photo.ID>, in postID: Post.ID) {
        guard canStack(ids, in: postID), let photos = post(postID)?.photos.filter({ ids.contains($0.id) }) else { return }
        let base = photos[0]

        asOneUndoStep {
            update(postID) { post in
                post.photos.removeAll { ids.contains($0.id) && $0.id != base.id }
                guard let index = post.photos.firstIndex(where: { $0.id == base.id }) else { return }
                post.photos[index].stacked = Array(photos.dropFirst())
            }
        }
        selectedPhotoIDs = [base.id]
        isPickingStack = false
        toast = Toast(message: "Stacked \(Self.photoCount(photos.count)) on one slide", systemImage: "square.stack", undoDepth: undoDepth)
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

    /// Spreads a photo across `count` slides, or back onto one. A stack always stays on one slide.
    func setSlideCount(_ count: Int, of id: Photo.ID, in postID: Post.ID) {
        guard let photo = photo(id, in: postID), !photo.isStack else { return }
        let clamped = min(max(count, 1), Photo.maxSlideCount)
        asOneUndoStep { updatePhoto(id, in: postID) { $0.slideCount = clamped } }
    }

    /// Crops for the photos of a stack, keyed by place: 0 is the top photo itself, 1 and 2 the ones below it.
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
