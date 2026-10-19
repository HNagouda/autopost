import Foundation
import Testing

@testable import AutopostCore

// Written by the first version, before photo adjustments, text boxes, saved ratios and Recently Deleted existed.
private let firstVersionLibrary = """
{
  "posts": [{
    "id": "7C0F6C2E-1D1B-4C55-9C51-0B3F4C1E2A10",
    "name": "Cali on film",
    "photos": [{"id": "2D0F6C2E-1D1B-4C55-9C51-0B3F4C1E2A10", "url": "file:///tmp/a.jpg"}],
    "frame": {
      "ratio": "portrait4x5", "customRatioWidth": 4, "customRatioHeight": 5, "borderPercent": 7,
      "verticalOffset": 0, "background": "color", "color": {"red": 1, "green": 1, "blue": 1},
      "hasShadow": false, "captionMode": "off", "captionText": ""
    }
  }],
  "defaultFrame": {},
  "presets": [],
  "export": {
    "size": "instagram1080", "quality": 0.92, "isSharpening": true, "keepsMetadata": true,
    "stripsLocation": true, "revealsInFinder": true, "destination": "file:///tmp/"
  }
}
"""

@Test func libraryFromFirstVersionStillLoads() throws {
    let library = try JSONDecoder().decode(Library.self, from: Data(firstVersionLibrary.utf8))

    #expect(library.posts[0].frame.borderPercent == 7)
    #expect(library.posts[0].frame.horizontalOffset == 0)
    #expect(library.posts[0].photos[0].textBoxes.isEmpty)
    #expect(library.savedRatios.isEmpty)
    #expect(library.deletedPosts.isEmpty)
}

@Test func libraryRoundTripsTextBoxes() throws {
    var library = Library()
    var post = Post(name: "Post 1", frame: FrameSettings())
    var photo = Photo(url: URL(fileURLWithPath: "/tmp/a.jpg"))
    var box = TextBox()
    box.text = "Kodak Gold 200"
    box.isItalic = true
    photo.textBoxes = [box]
    post.photos = [photo]
    library.posts = [post]

    let decoded = try JSONDecoder().decode(Library.self, from: JSONEncoder().encode(library))

    #expect(decoded.posts[0].photos[0].textBoxes == [box])
}
