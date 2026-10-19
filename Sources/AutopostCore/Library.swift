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

public struct Photo: Codable, Identifiable, Hashable, Sendable {
    public var id = UUID()
    public var url: URL

    public init(url: URL) {
        self.url = url
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

public struct Library: Codable, Sendable {
    public var posts: [Post] = []
    public var defaultFrame = FrameSettings()
    public var export = ExportSettings()
    public var presets: [FramePreset] = []

    public init() {}
}
