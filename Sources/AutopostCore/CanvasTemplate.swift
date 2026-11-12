import Foundation

/// A ready-made arrangement of the photos on a canvas. Every one works for any number of photos, and only places the
/// boxes: after applying it, each box can still be moved and resized.
///
/// Most of them use some photos as backgrounds, which fill their slides from edge to edge, and lay the others on
/// top across the seams. That is what makes a carousel read as one design while it is swiped. Those arrangements
/// are random within their style, so a regular pattern never shows: the same `seed` always gives the same one, and
/// a new seed gives another.
public enum CanvasTemplate: String, CaseIterable, Identifiable, Sendable {
    case overlay
    case overlayBordered
    case overlaySplit
    case overlayWide
    case overlaySmall
    case grid

    // The space kept between two photos on top of a background, in slide widths.
    static let margin = 0.06
    // The line of frame colour between two backgrounds, and the border of a print.
    static let gutter = 0.02

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .overlay: "Overlay"
        case .overlayBordered: "Overlay, Bordered"
        case .overlaySplit: "Overlay, Split"
        case .overlayWide: "Overlay, Wide"
        case .overlaySmall: "Overlay, Small"
        case .grid: "Grid"
        }
    }

    public var summary: String {
        switch self {
        case .overlay: "Backgrounds over one or two slides, with photos laid across them"
        case .overlayBordered: "The same, with a border around each photo on top, like a print"
        case .overlaySplit: "Backgrounds split by a thin line, with bordered photos on top"
        case .overlayWide: "Backgrounds over two or three slides, for a slow scroll"
        case .overlaySmall: "Backgrounds with small bordered photos on top, so more of them shows"
        case .grid: "Photos on the plain colour, four per slide"
        }
    }

    public struct Arrangement: Equatable, Sendable {
        // One box per photo, in the order of the photos from left to right.
        public var boxes: [CanvasBox]
        // Which of the boxes are backgrounds, drawn under the others.
        public var isBackground: [Bool]
        public var slideCount: Int
    }

    /// One box per photo. `slideRatio` is a slide's width over its height, which makes the margin above and below
    /// the photos as wide as the margin beside them.
    public func arrangement(photoCount: Int, slideRatio: Double, seed: UInt64) -> Arrangement {
        let count = max(photoCount, 1)
        var generator = SeededGenerator(seed: seed)
        let arrangement: Arrangement
        switch self {
        case .overlay: arrangement = Self.layered(count, style: .overlay, generator: &generator)
        case .overlayBordered: arrangement = Self.layered(count, style: .bordered, generator: &generator)
        case .overlaySplit: arrangement = Self.layered(count, style: .split, generator: &generator)
        case .overlayWide: arrangement = Self.layered(count, style: .wide, generator: &generator)
        case .overlaySmall: arrangement = Self.layered(count, style: .small, generator: &generator)
        case .grid: arrangement = Self.grid(count, slideRatio: slideRatio)
        }
        return Self.fitted(arrangement)
    }

    // How backgrounds and the photos on top of them are drawn in one of the overlay arrangements.
    private struct LayerStyle {
        // The line of frame colour between two backgrounds.
        var gutter = 0.0
        // The border of each photo on top.
        var insetBorder = 0.0
        // The widths a background may get, in slides. More than one slide makes the carousel scroll through it.
        var backgroundWidths: [Double] = [1, 2, 2]
        // The shapes a photo on top may take, as width in slide widths and height in slide heights.
        var insetShapes = LayerStyle.allShapes

        // Tall, wide, nearly square and small.
        static let allShapes: [(width: Double, height: Double)] = [(0.56, 0.76), (0.8, 0.46), (0.62, 0.56), (0.46, 0.4)]
        static let smallShapes: [(width: Double, height: Double)] = [(0.46, 0.4), (0.38, 0.46), (0.5, 0.32)]

        static let overlay = LayerStyle()
        static let bordered = LayerStyle(insetBorder: CanvasTemplate.gutter)
        // Joins half a slide off the seams put the line between two backgrounds in the middle of a slide.
        static let split = LayerStyle(gutter: CanvasTemplate.gutter, insetBorder: CanvasTemplate.gutter, backgroundWidths: [1, 1.5, 2])
        static let wide = LayerStyle(backgroundWidths: [2, 2, 3])
        static let small = LayerStyle(insetBorder: CanvasTemplate.gutter, insetShapes: LayerStyle.smallShapes)
    }

    // The photos on top keep this far from the top and bottom of the slide.
    private static let insetMarginY = 0.08
    // The share of the photos that become backgrounds, picked anew for each arrangement.
    private static let backgroundShare = 0.4...0.6

    /// Backgrounds side by side that fill every slide, with the other photos on top of them, centred on a seam or
    /// on the middle of a slide. About half the photos become backgrounds.
    private static func layered(_ count: Int, style: LayerStyle, generator: inout SeededGenerator) -> Arrangement {
        let backgroundCount = max(Int((Double(count) * Double.random(in: backgroundShare, using: &generator)).rounded()), 1)
        var widths = (0..<backgroundCount).map { _ in style.backgroundWidths.randomElement(using: &generator) ?? 1 }

        // The last background runs on to the end of its slide. Photos on top go on seams and slide middles, so
        // the backgrounds must be wide enough to have one such place for each.
        var slides = (widths.reduce(0, +) - 0.000_001).rounded(.up)
        while 2 * slides - 1 < Double(count - backgroundCount) {
            widths[Int.random(in: 0..<backgroundCount, using: &generator)] += 1
            slides += 1
        }
        widths[backgroundCount - 1] += slides - widths.reduce(0, +)

        var backgrounds: [CanvasBox] = []
        var left = 0.0
        for (index, width) in widths.enumerated() {
            let trimLeft = index == 0 ? 0 : style.gutter / 2
            let trimRight = index == backgroundCount - 1 ? 0 : style.gutter / 2
            backgrounds.append(CanvasBox(x: left + trimLeft, y: 0, width: width - trimLeft - trimRight, height: 1))
            left += width
        }

        let anchors = insetAnchors(count - backgroundCount, slides: slides, generator: &generator)
        let insets = anchors.map { anchor in
            let shape = style.insetShapes.randomElement(using: &generator) ?? LayerStyle.allShapes[0]
            // A photo never reaches the one beside it.
            let nearest = anchors.filter { $0 != anchor }.map { abs($0 - anchor) }.min() ?? .infinity
            let width = min(shape.width, nearest - margin)
            let top = Double.random(in: insetMarginY...(1 - insetMarginY - shape.height), using: &generator)
            return CanvasBox(x: anchor - width / 2, y: top, width: width, height: shape.height, border: style.insetBorder)
        }

        // From left to right, so the photos keep their order along the carousel. A background comes before a
        // photo centred on it.
        let placed = (backgrounds.map { ($0, true) } + insets.map { ($0, false) }).sorted { ($0.0.midX, $0.1 ? 0 : 1) < ($1.0.midX, $1.1 ? 0 : 1) }
        return Arrangement(boxes: placed.map(\.0), isBackground: placed.map(\.1), slideCount: Int(slides))
    }

    /// `count` different places for photos on top, each on a seam or the middle of a slide, a whole slide apart
    /// where there is room and half a slide where there is not.
    private static func insetAnchors(_ count: Int, slides: Double, generator: inout SeededGenerator) -> [Double] {
        let places = (1..<Int(2 * slides)).map { Double($0) / 2 }.shuffled(using: &generator)
        var chosen: [Double] = []
        for spacing in [1.0, 0.5] {
            for place in places where chosen.count < count && chosen.allSatisfy({ abs($0 - place) >= spacing }) {
                chosen.append(place)
            }
        }
        return chosen
    }

    private static func grid(_ count: Int, slideRatio: Double) -> Arrangement {
        let slideCount = CanvasGrid.slideCount(photoCount: count)
        let boxes = CanvasGrid.boxes(photoCount: count, slideCount: slideCount, slideRatio: slideRatio, spacing: CanvasGrid.defaultSpacing)
        return Arrangement(boxes: boxes, isBackground: Array(repeating: false, count: count), slideCount: slideCount)
    }

    /// An arrangement for more slides than Instagram allows, squeezed sideways onto the 20 it does.
    private static func fitted(_ arrangement: Arrangement) -> Arrangement {
        guard arrangement.slideCount > Photo.maxCanvasSlides else { return arrangement }
        let scale = Double(Photo.maxCanvasSlides) / Double(arrangement.slideCount)

        var fitted = arrangement
        fitted.slideCount = Photo.maxCanvasSlides
        for index in fitted.boxes.indices {
            fitted.boxes[index].x *= scale
            fitted.boxes[index].width *= scale
        }
        return fitted
    }
}

/// Random numbers that are the same every time for the same seed (SplitMix64), so an arrangement can be tested and
/// repeated.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
