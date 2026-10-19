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
    public var id = UUID()
    public var url: URL
    public var adjustments = PhotoAdjustments()
    public var textBoxes: [TextBox] = []

    public init(url: URL) {
        self.url = url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        adjustments = try container.decode(.adjustments, default: PhotoAdjustments())
        textBoxes = try container.decode(.textBoxes, default: [])
    }

    /// The same photo, border and text as a new entry, for duplicating a post.
    public func duplicated() -> Photo {
        var copy = Photo(url: url)
        copy.adjustments = adjustments
        copy.textBoxes = textBoxes.map { $0.duplicated() }
        return copy
    }
}

public struct Post: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var photos: [Photo] = []
    public var frame: FrameSettings
    public var lastExportedAt: Date?

    public init(name: String, frame: FrameSettings) {
        self.name = name
        self.frame = frame
    }

    /// The post's frame with this photo's own border and position applied.
    public func frame(for photo: Photo) -> FrameSettings {
        frame.applying(photo.adjustments)
    }
}

public struct FramePreset: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var frame: FrameSettings

    public init(name: String, frame: FrameSettings) {
        self.name = name
        self.frame = frame
    }
}

/// A deleted post, kept so it can be restored from Recently Deleted.
public struct DeletedPost: Codable, Identifiable, Sendable {
    public var post: Post
    public var deletedAt: Date

    public init(post: Post, deletedAt: Date) {
        self.post = post
        self.deletedAt = deletedAt
    }

    public var id: Post.ID { post.id }
}

public struct Library: Codable, Sendable {
    public var posts: [Post] = []
    public var defaultFrame = FrameSettings()
    public var export = ExportSettings()
    public var presets: [FramePreset] = []
    public var savedRatios: [SavedRatio] = []
    // The last text box placed or edited; a new box starts as a copy of it, in the same spot.
    public var textBoxTemplate: TextBox?
    public var deletedPosts: [DeletedPost] = []

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
    }
}
