import Foundation
import Testing

@testable import AutopostCore

private func url(_ path: String) -> URL {
    URL(fileURLWithPath: path)
}

/// A library whose photos were all in /Pictures/roll before the roll moved to /Pictures/film, plus one photo that never moved.
private func movedRoll() -> Library {
    var post = Post(name: "Hazy", frame: FrameSettings())
    var stack = Photo(url: url("/Pictures/roll/3.jpg"))
    stack.stacked = [Photo(url: url("/Pictures/roll/4.jpg"))]
    post.photos = [Photo(url: url("/Pictures/roll/1.jpg")), Photo(url: url("/Pictures/roll/2.jpg")), stack, Photo(url: url("/Pictures/here.jpg"))]

    var library = Library()
    library.posts = [post]
    return library
}

private let onDisk: Set<String> = ["/Pictures/film/1.jpg", "/Pictures/film/2.jpg", "/Pictures/film/3.jpg", "/Pictures/film/4.jpg", "/Pictures/here.jpg"]

@Test func locatingOneMovedPhotoFindsTheOthersInTheSameFolder() {
    var library = movedRoll()
    let changed = library.relink(url("/Pictures/roll/1.jpg"), to: url("/Pictures/film/1.jpg")) { onDisk.contains($0.path) }

    let paths = library.posts[0].photos.flatMap(\.images).map(\.url.path)
    #expect(changed == 4)
    #expect(paths == ["/Pictures/film/1.jpg", "/Pictures/film/2.jpg", "/Pictures/film/3.jpg", "/Pictures/film/4.jpg", "/Pictures/here.jpg"])
}

@Test func photoThatStillExistsIsNeverRelinked() {
    var library = movedRoll()
    // here.jpg exists both where it is and in the new folder; it stays where it is.
    _ = library.relink(url("/Pictures/roll/1.jpg"), to: url("/Pictures/film/1.jpg")) { onDisk.union(["/Pictures/film/here.jpg"]).contains($0.path) }

    #expect(library.posts[0].photos[3].url.path == "/Pictures/here.jpg")
}

@Test func photosInRecentlyDeletedAreRelinkedToo() {
    var library = movedRoll()
    library.deletedPosts = [DeletedPost(post: library.posts.removeFirst(), deletedAt: Date())]
    _ = library.relink(url("/Pictures/roll/1.jpg"), to: url("/Pictures/film/1.jpg")) { onDisk.contains($0.path) }

    #expect(library.deletedPosts[0].post.photos[1].url.path == "/Pictures/film/2.jpg")
}
