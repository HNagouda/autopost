import AutopostCore
import Foundation

/// Canvases: several photos placed freely across a run of slides.
extension LibraryStore {
    /// Makes a canvas of the selection, or else lets the user click the photos for it. Returns the new canvas.
    func startCanvas(in postID: Post.ID) -> Photo.ID? {
        if !selectedPhotoIDs.isEmpty, pickingLayout != .stack { return makeCanvas(of: selectedPhotoIDs, in: postID) }
        selectedPhotoIDs = []
        pickingLayout = .canvas
        return nil
    }

    /// Puts the photos on one canvas at the place of the first one, in carousel order, arranged as backgrounds with photos over the seams.
    @discardableResult
    func makeCanvas(of ids: Set<Photo.ID>, in postID: Post.ID) -> Photo.ID? {
        guard let post = post(postID) else { return nil }
        let photos = post.photos.filter { ids.contains($0.id) }
        guard let canvas = Photo.canvas(of: photos, template: .overlay, slideRatio: Self.slideRatio(of: post), seed: .random(in: 0 ... .max)) else { return nil }

        asOneUndoStep {
            update(postID) { post in
                guard let index = post.photos.firstIndex(where: { $0.id == canvas.id }) else { return }
                post.photos[index] = canvas
                post.photos.removeAll { ids.contains($0.id) && $0.id != canvas.id }
            }
        }
        selectedPhotoIDs = [canvas.id]
        pickingLayout = nil
        toast = Toast(message: "Made a canvas of \(Self.photoCount(canvas.images.count))", systemImage: "rectangle.3.group", undoDepth: undoDepth)
        return canvas.id
    }

    /// Gives every photo of the canvas its own slide again, where the canvas was.
    func breakCanvasApart(_ id: Photo.ID, in postID: Post.ID) {
        guard let photo = photo(id, in: postID), photo.isCanvas else { return }
        let photos = photo.brokenApart

        asOneUndoStep {
            update(postID) { post in
                guard let index = post.photos.firstIndex(where: { $0.id == id }) else { return }
                post.photos.replaceSubrange(index...index, with: photos)
            }
        }
        selectedPhotoIDs = Set(photos.map(\.id))
        toast = Toast(message: "Broke the canvas into \(Self.photoCount(photos.count))", systemImage: "rectangle.3.group", undoDepth: undoDepth)
    }

    /// Moves or resizes one photo of a canvas. Drags call this many times, which undo merges into one step.
    func setCanvasBox(_ box: CanvasBox, at index: Int, of id: Photo.ID, in postID: Post.ID) {
        updatePhoto(id, in: postID) { photo in
            guard photo.boxes.indices.contains(index) else { return }
            photo.boxes[index] = box.kept(onSlides: photo.slideCount)
        }
    }

    /// Arranges the canvas anew. Most arrangements are random within their style, so each call gives another one.
    func arrangeCanvas(_ id: Photo.ID, in postID: Post.ID, as template: CanvasTemplate) {
        guard let post = post(postID) else { return }
        asOneUndoStep {
            updatePhoto(id, in: postID) { $0.arrange(template, slideRatio: Self.slideRatio(of: post), seed: .random(in: 0 ... .max)) }
        }
    }

    /// Changes how many slides the canvas runs over. A grid is laid out again over the new count. Photos placed
    /// by hand keep their places; ones past the new end are pulled back in.
    func setCanvasSlideCount(_ count: Int, of id: Photo.ID, in postID: Post.ID) {
        guard let post = post(postID) else { return }
        asOneUndoStep {
            updatePhoto(id, in: postID) { photo in
                guard photo.isCanvas else { return }
                photo.setCanvasSlideCount(count)
                photo.boxes = photo.boxes.map { $0.kept(onSlides: photo.slideCount) }
                photo.regrid(slideRatio: Self.slideRatio(of: post))
            }
        }
    }

    /// The space around and between the photos of a grid. Dragging the slider calls this many times, which undo
    /// merges into one step.
    func setCanvasGridSpacing(_ spacing: Double, of id: Photo.ID, in postID: Post.ID) {
        guard let post = post(postID) else { return }
        updatePhoto(id, in: postID) { photo in
            guard photo.gridSpacing != nil else { return }
            photo.gridSpacing = spacing
            photo.regrid(slideRatio: Self.slideRatio(of: post))
        }
    }

    /// Ends a drag in a grid: the dragged photo swaps with the one it was dropped on, or goes back to its own cell.
    func dropCanvasImage(_ index: Int, onto target: Int?, of id: Photo.ID, in postID: Post.ID) {
        guard let post = post(postID) else { return }
        updatePhoto(id, in: postID) { photo in
            if let target { photo.swapImages(index, target) }
            photo.regrid(slideRatio: Self.slideRatio(of: post))
        }
    }

    /// Keeps the photos of a grid where they are and lets them be moved and resized by hand from now on.
    func editCanvasFreely(_ id: Photo.ID, in postID: Post.ID) {
        asOneUndoStep { updatePhoto(id, in: postID) { $0.gridSpacing = nil } }
    }

    /// Draws the photo at `index` over all the others, or under them.
    func moveCanvasImage(_ index: Int, toFront: Bool, of id: Photo.ID, in postID: Post.ID) {
        asOneUndoStep { updatePhoto(id, in: postID) { $0.moveImage(from: index, to: toFront ? $0.images.count - 1 : 0) } }
    }

    /// Makes the photo at `index` fill every slide it touches, with no border, and draws it under all the others.
    func useCanvasImageAsBackground(_ index: Int, of id: Photo.ID, in postID: Post.ID) {
        asOneUndoStep {
            updatePhoto(id, in: postID) { photo in
                guard photo.boxes.indices.contains(index) else { return }
                photo.boxes[index] = photo.boxes[index].asBackground(onSlides: photo.slideCount)
                photo.moveImage(from: index, to: 0)
            }
        }
    }

    /// Takes one photo off the canvas and puts it back in the post, right after the canvas.
    func removeCanvasImage(_ index: Int, of id: Photo.ID, in postID: Post.ID) {
        var removed: Photo?
        asOneUndoStep {
            update(postID) { post in
                guard let place = post.photos.firstIndex(where: { $0.id == id }) else { return }
                removed = post.photos[place].removeImage(at: index)
                post.photos[place].regrid(slideRatio: Self.slideRatio(of: post))
                if let removed { post.photos.insert(removed, at: place + 1) }
            }
        }
        guard let removed else { return }
        toast = Toast(message: "Took \(removed.url.lastPathComponent) off the canvas", systemImage: "rectangle.3.group", undoDepth: undoDepth)
    }

    func addPhotos(_ urls: [URL], toCanvas id: Photo.ID, in postID: Post.ID) {
        guard !urls.isEmpty, let post = post(postID) else { return }
        asOneUndoStep {
            updatePhoto(id, in: postID) { photo in
                photo.addImages(urls)
                photo.regrid(slideRatio: Self.slideRatio(of: post))
            }
        }
    }

    /// Width over height of one slide of a canvas in this post.
    static func slideRatio(of post: Post) -> Double {
        post.frame.ratioValue ?? Photo.canvasFallbackRatio
    }
}
