import Foundation

/// Pointing photos at files that were moved or renamed on disk.
///
/// Autopost keeps a path to each photo rather than a copy, so tidying up the Pictures folder leaves photos missing.
/// When one is found again, the others usually moved with it, as Lightroom assumes when it relinks a folder.
extension Library {
    /// Points every photo at `old` to `new`, and every other photo whose file is gone to a file of the same name in
    /// `new`'s folder, when there is one. Deleted posts are included, so restoring one later finds its photos too.
    /// Returns how many photos now point somewhere new.
    public mutating func relink(_ old: URL, to new: URL, fileExists: (URL) -> Bool) -> Int {
        let folder = new.deletingLastPathComponent()
        var changed = 0

        func relinked(_ url: URL) -> URL? {
            if url == old { return new }
            guard !fileExists(url) else { return nil }
            let candidate = folder.appendingPathComponent(url.lastPathComponent)
            return fileExists(candidate) ? candidate : nil
        }

        func relinkImages(of photo: inout Photo) {
            if let url = relinked(photo.url) {
                photo.url = url
                changed += 1
            }
            for index in photo.stacked.indices {
                if let url = relinked(photo.stacked[index].url) {
                    photo.stacked[index].url = url
                    changed += 1
                }
            }
        }

        for post in posts.indices {
            for photo in posts[post].photos.indices { relinkImages(of: &posts[post].photos[photo]) }
        }
        for deleted in deletedPosts.indices {
            for photo in deletedPosts[deleted].post.photos.indices { relinkImages(of: &deletedPosts[deleted].post.photos[photo]) }
        }

        return changed
    }
}
