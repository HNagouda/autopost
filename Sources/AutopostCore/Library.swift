import Foundation

public enum ExportSize: String, Codable, CaseIterable, Identifiable, Sendable {
    case instagram1080
    case instagram1440
    case large2160
    case fullResolution

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .instagram1080: "1080 px · Instagram"
        case .instagram1440: "1440 px"
        case .large2160: "2160 px"
        case .fullResolution: "Full resolution"
        }
    }

    // Instagram stores feed photos 1080 px wide; anything larger gets resampled by Instagram instead of by us.
    public var fixedWidth: Int? {
        switch self {
        case .instagram1080: 1080
        case .instagram1440: 1440
        case .large2160: 2160
        case .fullResolution: nil
        }
    }
}

public struct ExportSettings: Codable, Equatable, Sendable {
    public var size: ExportSize = .instagram1080
    public var quality = 0.92
    public var isSharpening = true
    public var keepsMetadata = true
    public var stripsLocation = true
    public var revealsInFinder = true
    public var destination = FileManager.default
        .urls(for: .picturesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Autopost Exports", isDirectory: true)

    public init() {}
}

public struct Photo: Codable, Identifiable, Equatable, Sendable {
    // Instagram shows one slide at a time, so a panorama over more than three slides gets too thin to read.
    public static let maxSlideCount = 3
    // Three landscape photos already fill a portrait slide; a fourth would be a strip.
    public static let maxStackSize = 3

    public var id = UUID()
    public var url: URL
    public var adjustments = PhotoAdjustments()
    public var textBoxes: [TextBox] = []
    public var crop = CropRect.full
    // Camera settings typed over the EXIF for this photo, or for a film scan that has none.
    public var cameraOverrides = CameraSettings()
    // How many carousel slides the photo is spread across, 1 to maxSlideCount. Over two or more slides a wide photo
    // scrolls past as one picture.
    public var slideCount = 1
    // Photos drawn below this one on the same slide, top to bottom. Their own borders and text are kept, unused,
    // so unstacking gives back exactly the photos that went in.
    public var stacked: [Photo] = []

    public init(url: URL) {
        self.url = url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        adjustments = try container.decode(.adjustments, default: PhotoAdjustments())
        textBoxes = try container.decode(.textBoxes, default: [])
        // A hand-edited or damaged file must not turn into a zero or NaN layout, so a crop that is not a valid part
        // of the photo is dropped.
        let decodedCrop = try container.decode(.crop, default: CropRect.full)
        crop = decodedCrop.isValid ? decodedCrop : .full
        cameraOverrides = try container.decode(.cameraOverrides, default: CameraSettings())
        // A stack never spans slides and never holds another stack, so a hand-edited file can't ask for either.
        let decodedStack = try container.decode(.stacked, default: [Photo]())
        stacked = decodedStack.prefix(Self.maxStackSize - 1).map(\.unstackedSingle)
        let decodedSlides = try container.decode(.slideCount, default: 1)
        slideCount = stacked.isEmpty ? min(max(decodedSlides, 1), Self.maxSlideCount) : 1
    }

    /// The photos drawn on this photo's slide, top to bottom: itself, then the ones stacked below it.
    public var images: [Photo] { [self] + stacked }

    public var isStack: Bool { !stacked.isEmpty }

    /// This photo on its own, on one slide.
    var unstackedSingle: Photo {
        var single = self
        single.stacked = []
        single.slideCount = 1
        return single
    }

    /// The same photo, border, crop and text as a new entry, for duplicating a post.
    public func duplicated() -> Photo {
        var copy = Photo(url: url)
        copy.adjustments = adjustments
        copy.crop = crop
        copy.cameraOverrides = cameraOverrides
        copy.textBoxes = textBoxes.map { $0.duplicated() }
        copy.slideCount = slideCount
        copy.stacked = stacked.map { $0.duplicated() }
        return copy
    }
}

public struct Post: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var name: String
    public var photos: [Photo] = []
    public var frame: FrameSettings
    public var lastExportedAt: Date?

    public init(name: String, frame: FrameSettings) {
        self.name = name
        self.frame = frame
    }

    /// The carousel as Instagram shows it: one entry per slide, so a photo spread over two slides appears twice.
    public var slides: [Slide] {
        photos.flatMap { photo in (0..<photo.slideCount).map { Slide(photo: photo, index: $0) } }
    }

    /// The post's frame with this photo's own border and position applied.
    public func frame(for photo: Photo) -> FrameSettings {
        frame.applying(photo.adjustments)
    }
}

/// One slide of a carousel: a photo, or one part of a photo spread over several slides.
public struct Slide: Identifiable, Equatable, Sendable {
    public var photo: Photo
    // Which part of the photo, counted from 0 at the left.
    public var index: Int

    public var id: String { "\(photo.id)-\(index)" }
}

public struct FramePreset: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var name: String
    public var frame: FrameSettings

    public init(name: String, frame: FrameSettings) {
        self.name = name
        self.frame = frame
    }
}

/// A deleted post, kept so it can be restored from Recently Deleted.
public struct DeletedPost: Codable, Identifiable, Equatable, Sendable {
    public var post: Post
    public var deletedAt: Date

    public init(post: Post, deletedAt: Date) {
        self.post = post
        self.deletedAt = deletedAt
    }

    public var id: Post.ID { post.id }
}

public struct Library: Codable, Equatable, Sendable {
    public var posts: [Post] = []
    public var defaultFrame = FrameSettings()
    public var export = ExportSettings()
    public var presets: [FramePreset] = []
    public var savedRatios: [SavedRatio] = []
    // The last text box placed or edited; a new box starts as a copy of it, in the same spot.
    public var textBoxTemplate: TextBox?
    public var deletedPosts: [DeletedPost] = []
    // The names to print for camera models, keyed by the model in the EXIF: "ILCE-6400" to "Sony a6400".
    public var cameraNames: [String: String] = [:]

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        posts = try container.decode(.posts, default: [])
        defaultFrame = try container.decode(.defaultFrame, default: FrameSettings())
        export = try container.decode(.export, default: ExportSettings())
        presets = try container.decode(.presets, default: [])
        savedRatios = try container.decode(.savedRatios, default: [])
        textBoxTemplate = try container.decodeIfPresent(TextBox.self, forKey: .textBoxTemplate)
        deletedPosts = try container.decode(.deletedPosts, default: [])
        cameraNames = try container.decode(.cameraNames, default: [:])
    }
}
