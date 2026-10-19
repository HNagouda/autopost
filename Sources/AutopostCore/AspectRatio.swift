import Foundation

public enum AspectRatio: String, Codable, CaseIterable, Identifiable, Sendable {
    case portrait4x5
    case portrait3x4
    case story9x16
    case square
    case original
    case landscape5x4
    case landscape4x3
    case landscape3x2
    case landscape191x1
    case landscape16x9
    case landscape2x1
    case custom

    public var id: String { rawValue }

    // Grouped this way in the ratio picker. Custom has its own row.
    public static let portrait: [AspectRatio] = [.portrait4x5, .portrait3x4, .story9x16]
    public static let squareAndOriginal: [AspectRatio] = [.square, .original]
    public static let landscape: [AspectRatio] = [.landscape5x4, .landscape4x3, .landscape3x2, .landscape191x1, .landscape16x9, .landscape2x1]

    public var label: String {
        switch self {
        case .portrait4x5: "4:5"
        case .portrait3x4: "3:4"
        case .story9x16: "9:16"
        case .square: "1:1"
        case .original: "Original"
        case .landscape5x4: "5:4"
        case .landscape4x3: "4:3"
        case .landscape3x2: "3:2"
        case .landscape191x1: "1.91:1"
        case .landscape16x9: "16:9"
        case .landscape2x1: "2:1"
        case .custom: "Custom"
        }
    }

    public var detail: String {
        switch self {
        case .portrait4x5: "Portrait feed"
        case .portrait3x4: "Tall feed, matches the profile grid"
        case .story9x16: "Story or reel"
        case .square: "Square"
        case .original: "Even border, keeps the photo's shape"
        case .landscape5x4: "Slightly wide, like large format film"
        case .landscape4x3: "Micro Four Thirds and phone sensors"
        case .landscape3x2: "35mm film and most camera sensors"
        case .landscape191x1: "Widest the Instagram feed allows"
        case .landscape16x9: "Widescreen"
        case .landscape2x1: "Panorama"
        case .custom: "Your own ratio"
        }
    }

    /// Width divided by height, or nil when the photo or the custom fields decide.
    public var fixedValue: Double? {
        switch self {
        case .portrait4x5: 4.0 / 5.0
        case .portrait3x4: 3.0 / 4.0
        case .story9x16: 9.0 / 16.0
        case .square: 1
        case .landscape5x4: 5.0 / 4.0
        case .landscape4x3: 4.0 / 3.0
        case .landscape3x2: 3.0 / 2.0
        case .landscape191x1: 1.91
        case .landscape16x9: 16.0 / 9.0
        case .landscape2x1: 2
        case .original, .custom: nil
        }
    }
}

/// A custom ratio the user kept, like 32:9, offered next to the built-in ones.
public struct SavedRatio: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public var label: String { "\(width.formatted()):\(height.formatted())" }
}

/// Instagram feed posts must sit between 4:5 and 1.91:1; anything outside gets cropped on upload.
public enum InstagramFeed {
    public static let tallestRatio = 4.0 / 5.0
    public static let widestRatio = 1.91

    public static func fits(_ ratio: Double) -> Bool {
        // A little slack, so 1.91 itself and rounding noise count as fitting.
        ratio >= tallestRatio - 0.001 && ratio <= widestRatio + 0.001
    }
}
