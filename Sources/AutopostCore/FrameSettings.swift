import Foundation

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

/// Per-photo changes to the post's frame. Nil means "same as the post".
public struct PhotoAdjustments: Codable, Equatable, Sendable {
    public var borderPercent: Double?
    public var verticalOffset: Double?
    public var horizontalOffset: Double?

    public init() {}

    public var isEmpty: Bool { borderPercent == nil && verticalOffset == nil && horizontalOffset == nil }
}

public struct FrameSettings: Codable, Equatable, Sendable {
    public var ratio: AspectRatio = .portrait4x5
    public var customRatioWidth: Double = 4
    public var customRatioHeight: Double = 5
    // Smallest border on any side, as a percentage of the canvas width.
    public var borderPercent: Double = 5
    // -1 pushes the photo to the top of the free space, 1 to the bottom.
    public var verticalOffset: Double = 0
    // -1 pushes the photo to the left of the free space, 1 to the right.
    public var horizontalOffset: Double = 0
    public var background: FrameBackground = .color
    public var color: FrameColor = .white
    public var hasShadow = false
    public var captionMode: CaptionMode = .off
    public var captionText = ""

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = FrameSettings()
        ratio = try container.decode(.ratio, default: defaults.ratio)
        customRatioWidth = try container.decode(.customRatioWidth, default: defaults.customRatioWidth)
        customRatioHeight = try container.decode(.customRatioHeight, default: defaults.customRatioHeight)
        borderPercent = try container.decode(.borderPercent, default: defaults.borderPercent)
        verticalOffset = try container.decode(.verticalOffset, default: defaults.verticalOffset)
        horizontalOffset = try container.decode(.horizontalOffset, default: defaults.horizontalOffset)
        background = try container.decode(.background, default: defaults.background)
        color = try container.decode(.color, default: defaults.color)
        hasShadow = try container.decode(.hasShadow, default: defaults.hasShadow)
        captionMode = try container.decode(.captionMode, default: defaults.captionMode)
        captionText = try container.decode(.captionText, default: defaults.captionText)
    }

    public func uses(_ saved: SavedRatio) -> Bool {
        ratio == .custom && customRatioWidth == saved.width && customRatioHeight == saved.height
    }

    public mutating func use(_ saved: SavedRatio) {
        ratio = .custom
        customRatioWidth = saved.width
        customRatioHeight = saved.height
    }

    /// This frame with one photo's own border and position on top.
    public func applying(_ adjustments: PhotoAdjustments) -> FrameSettings {
        var frame = self
        frame.borderPercent = adjustments.borderPercent ?? borderPercent
        frame.verticalOffset = adjustments.verticalOffset ?? verticalOffset
        frame.horizontalOffset = adjustments.horizontalOffset ?? horizontalOffset
        return frame
    }

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
