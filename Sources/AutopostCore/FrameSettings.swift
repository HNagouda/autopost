import Foundation

public enum AspectRatio: String, Codable, CaseIterable, Identifiable, Sendable {
    case portrait4x5
    case portrait3x4
    case square
    case landscape191x1
    case story9x16
    case original
    case custom

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .portrait4x5: "4:5"
        case .portrait3x4: "3:4"
        case .square: "1:1"
        case .landscape191x1: "1.91:1"
        case .story9x16: "9:16"
        case .original: "Original"
        case .custom: "Custom"
        }
    }

    public var detail: String {
        switch self {
        case .portrait4x5: "Portrait feed"
        case .portrait3x4: "Tall feed, matches the profile grid"
        case .square: "Square"
        case .landscape191x1: "Landscape feed"
        case .story9x16: "Story or reel"
        case .original: "Even border, keeps the photo's shape"
        case .custom: "Your own ratio"
        }
    }

    /// Width divided by height, or nil when the photo or the custom fields decide.
    public var fixedValue: Double? {
        switch self {
        case .portrait4x5: 4.0 / 5.0
        case .portrait3x4: 3.0 / 4.0
        case .square: 1
        case .landscape191x1: 1.91
        case .story9x16: 9.0 / 16.0
        case .original, .custom: nil
        }
    }
}

public enum FrameBackground: String, Codable, CaseIterable, Sendable {
    case color
    case blur
}

public enum CaptionMode: String, Codable, CaseIterable, Sendable {
    case off
    case exif
    case custom
}

public struct FrameColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let white = FrameColor(red: 1, green: 1, blue: 1)

    // Rec. 709 weights, good enough to choose between dark and light caption text.
    public var isLight: Bool { 0.2126 * red + 0.7152 * green + 0.0722 * blue > 0.5 }
}

public struct FrameSettings: Codable, Equatable, Sendable {
    public var ratio: AspectRatio = .portrait4x5
    public var customRatioWidth: Double = 4
    public var customRatioHeight: Double = 5
    // Smallest border on any side, as a percentage of the canvas width.
    public var borderPercent: Double = 5
    // -1 pushes the photo to the top of the free space, 1 to the bottom.
    public var verticalOffset: Double = 0
    public var background: FrameBackground = .color
    public var color: FrameColor = .white
    public var hasShadow = false
    public var captionMode: CaptionMode = .off
    public var captionText = ""

    public init() {}

    /// Canvas width divided by height, or nil when the canvas follows the photo.
    public var ratioValue: Double? {
        if ratio == .custom {
            guard customRatioWidth > 0, customRatioHeight > 0 else { return nil }
            return customRatioWidth / customRatioHeight
        }
        return ratio.fixedValue
    }

    public var ratioLabel: String {
        if ratio == .custom {
            return "\(customRatioWidth.formatted()):\(customRatioHeight.formatted())"
        }
        return ratio.label
    }

    /// The caption to print for a photo, or nil when there is nothing to print.
    public func caption(exifLine: String?) -> String? {
        switch captionMode {
        case .off: return nil
        case .exif: return exifLine
        case .custom:
            let text = captionText.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
    }
}
