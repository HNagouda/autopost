import CoreGraphics
import Foundation

/// Where one photo sits on a canvas: a run of slides laid out as one wide picture, on which photos are placed freely
/// and may cross from one slide into the next.
///
/// `x` and `width` are in slide widths, so 1.5 is the middle of the second slide. `y` and `height` are fractions of
/// the slide height. Counting in slides keeps a box where it is when slides are added at the end.
public struct CanvasBox: Codable, Equatable, Sendable {
    // Smaller than this a box is too hard to grab again.
    public static let minimumSide = 0.05
    // Where a photo added to a canvas lands on the first slide, and how far the next one is moved right and down
    // from it. After this many steps they start again at the first place.
    static let addedOrigin = 0.2
    static let addedWidth = 0.6
    static let addedHeight = 0.5
    static let addedStep = 0.04
    static let addedSteps = 8
    // Far larger than any box made by hand. A damaged library must not ask the exporter for an endless bitmap.
    public static let maximumWidth = 2 * Double(Photo.maxCanvasSlides)
    public static let maximumHeight = 3.0

    // Wider than this the border leaves too little of a small photo to see.
    public static let maxBorder = 0.08

    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    // A border in the post's frame colour inside the box, in slide widths, like the white edge of a print. 0 is none.
    public var border = 0.0
    // How much the photo is blurred, from 0 for sharp to 1 for the most. A blurred background lets the photos on
    // top of it stand out.
    public var blur = 0.0

    // The blur at 1, as a fraction of the slide width.
    public static let maxBlurFraction = 0.04
    // The blur a photo gets when its blur is switched on.
    public static let defaultBlur = 0.4

    public init(x: Double, y: Double, width: Double, height: Double, border: Double = 0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.border = border
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = try container.decode(Double.self, forKey: .x)
        y = try container.decode(Double.self, forKey: .y)
        width = try container.decode(Double.self, forKey: .width)
        height = try container.decode(Double.self, forKey: .height)
        border = try container.decode(.border, default: 0)
        blur = try container.decode(.blur, default: 0)
    }

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }

    /// The box at least `minimumSide` big and with at least that much of it on the canvas, so it can hang over an
    /// edge but never get lost outside it.
    public func kept(onSlides slideCount: Int) -> CanvasBox {
        var box = self
        box.width = min(max(width.isFinite ? width : 1, Self.minimumSide), Self.maximumWidth)
        box.height = min(max(height.isFinite ? height : 1, Self.minimumSide), Self.maximumHeight)
        box.x = min(max(x.isFinite ? x : 0, Self.minimumSide - box.width), Double(slideCount) - Self.minimumSide)
        box.y = min(max(y.isFinite ? y : 0, Self.minimumSide - box.height), 1 - Self.minimumSide)
        box.border = min(max(border.isFinite ? border : 0, 0), Self.maxBorder)
        box.blur = min(max(blur.isFinite ? blur : 0, 0), 1)
        return box
    }

    /// The box filling the whole height of every slide it touches, with no border: a background for other photos.
    public func asBackground(onSlides slideCount: Int) -> CanvasBox {
        let start = min(max(x.rounded(.down), 0), Double(slideCount - 1))
        let end = min(max((maxX - 0.000_001).rounded(.up), start + 1), Double(slideCount))
        var background = CanvasBox(x: start, y: 0, width: end - start, height: 1)
        background.blur = blur
        return background
    }
}

extension Photo {
    // Instagram's limit for a whole carousel.
    public static let maxCanvasSlides = 20
    // The slide shape a canvas uses when the post keeps each photo's original ratio, which a canvas has none of.
    public static let canvasFallbackRatio = 0.8

    /// True when the photos of this entry are placed freely by `boxes` rather than fitted or stacked.
    public var isCanvas: Bool { !boxes.isEmpty }

    /// One canvas holding every photo of `photos`, stacks taken apart, arranged by `template`. The first photo's
    /// text boxes become the canvas's.
    public static func canvas(of photos: [Photo], template: CanvasTemplate, slideRatio: Double, seed: UInt64) -> Photo? {
        let singles = photos.flatMap(\.images).map(\.unstackedSingle)
        guard var canvas = singles.first else { return nil }

        canvas.stacked = Array(singles.dropFirst())
        canvas.adjustments = PhotoAdjustments()
        canvas.arrange(template, slideRatio: slideRatio, seed: seed)
        return canvas
    }

    /// Places every photo of the canvas anew, and sets the slide count the arrangement needs. The photos keep their
    /// order from left to right, and the ones the arrangement uses as backgrounds are drawn first, under the others.
    /// A new `seed` gives another variation of the same arrangement.
    public mutating func arrange(_ template: CanvasTemplate, slideRatio: Double, seed: UInt64) {
        // A grid stays a grid afterwards: it is laid out again whenever its slides, spacing or photos change.
        gridSpacing = template == .grid ? CanvasGrid.defaultSpacing : nil
        let arrangement = template.arrangement(photoCount: images.count, slideRatio: slideRatio, seed: seed)
        var parts = imageParts
        if boxes.count == parts.count {
            let leftToRight = parts.indices.sorted { (boxes[$0].midX, $0) < (boxes[$1].midX, $1) }
            parts = leftToRight.map { parts[$0] }
        }

        let drawingOrder = parts.indices.filter { arrangement.isBackground[$0] } + parts.indices.filter { !arrangement.isBackground[$0] }
        setParts(drawingOrder.map { parts[$0] }, boxes: drawingOrder.map { arrangement.boxes[$0] })
        setCanvasSlideCount(arrangement.slideCount)
    }

    /// Sets how many slides the canvas runs over. A text box is placed as a fraction of the whole canvas's width, so
    /// each one is moved to stay over the same spot on the slides.
    public mutating func setCanvasSlideCount(_ count: Int) {
        let old = Double(slideCount)
        slideCount = min(max(count, 1), Self.maxCanvasSlides)
        for index in textBoxes.indices {
            textBoxes[index].x = min(textBoxes[index].x * old / Double(slideCount), 1)
        }
    }

    /// Lays the photos of a grid out again over the canvas's slides. Does nothing to a canvas placed by hand.
    public mutating func regrid(slideRatio: Double) {
        guard isCanvas, let gridSpacing else { return }
        let cells = CanvasGrid.boxes(photoCount: images.count, slideCount: slideCount, slideRatio: slideRatio, spacing: gridSpacing)
        boxes = zip(cells, boxes).map { cell, old in
            var box = cell
            box.border = old.border
            box.blur = old.blur
            return box
        }
    }

    /// Exchanges two photos of the canvas or stack: each takes the other's place and keeps its own crop.
    public mutating func swapImages(_ first: Int, _ second: Int) {
        guard isCanvas || isStack, images.indices.contains(first), images.indices.contains(second), first != second else { return }
        var parts = imageParts
        parts.swapAt(first, second)
        setParts(parts, boxes: boxes)
    }

    /// The photos of a canvas as separate entries again, in drawing order. The first keeps the canvas's text boxes.
    public var brokenApart: [Photo] {
        return [unstackedSingle] + stacked
    }

    /// Moves the photo at `index` to another place in the drawing order; the last place is drawn on top.
    public mutating func moveImage(from index: Int, to destination: Int) {
        guard isCanvas, images.indices.contains(index), images.indices.contains(destination), index != destination else { return }
        var parts = imageParts
        var placed = boxes
        parts.insert(parts.remove(at: index), at: destination)
        placed.insert(placed.remove(at: index), at: destination)
        setParts(parts, boxes: placed)
    }

    /// Takes the photo at `index` off the canvas or out of the stack and returns it as an entry of its own. The
    /// last photo stays, so a stack of two becomes a single photo.
    public mutating func removeImage(at index: Int) -> Photo? {
        guard isCanvas || isStack, images.count > 1, images.indices.contains(index) else { return nil }
        var parts = imageParts
        var placed = boxes
        let removed = parts.remove(at: index)
        // A stack has no boxes: its photos are placed by the layout.
        if isCanvas { placed.remove(at: index) }
        setParts(parts, boxes: placed)

        // A photo from below the first one comes back with the text and border it had before it joined.
        var photo = removed.kept ?? Photo(url: removed.url)
        photo.url = removed.url
        photo.crop = removed.crop
        photo.cameraOverrides = removed.cameraOverrides
        return photo
    }

    /// Adds photos on top of the canvas, each a little further right and down so none hides the one before.
    public mutating func addImages(_ urls: [URL]) {
        guard isCanvas else { return }
        for url in urls {
            let step = Double(boxes.count % CanvasBox.addedSteps) * CanvasBox.addedStep
            stacked.append(Photo(url: url))
            boxes.append(CanvasBox(x: CanvasBox.addedOrigin + step, y: CanvasBox.addedOrigin + step, width: CanvasBox.addedWidth, height: CanvasBox.addedHeight)
                .kept(onSlides: slideCount))
        }
    }

    /// A new text box moved to where it can be seen on this canvas: the middle of the photo at `index`, or of the
    /// first slide. A box made for an ordinary photo sits low in the middle of the whole canvas, which on a long
    /// canvas is far off screen, and is dark, which does not show on a photo.
    public func placingOnCanvas(_ box: TextBox, overImage index: Int?) -> TextBox {
        guard isCanvas else { return box }
        let target = index.flatMap { boxes.indices.contains($0) ? boxes[$0] : nil }
        let x = min(max(target?.midX ?? 0.5, 0), Double(slideCount))
        let y = min(max(target?.midY ?? 0.5, 0), 1)

        var placed = box
        placed.x = x / Double(slideCount)
        placed.y = y
        let isOnPhoto = boxes.contains { $0.x <= x && x <= $0.maxX && $0.y <= y && y <= $0.maxY }
        if isOnPhoto, !box.color.isLight { placed.color = FrameColor(red: 0.95, green: 0.95, blue: 0.95) }
        return placed
    }

    // What belongs to one photo of a canvas or stack and moves with it when the photos change places. The entry's id,
    // text boxes, border and slide count belong to the whole canvas or stack, and stay where they are.
    private struct ImagePart {
        var url: URL
        var crop: CropRect
        var cameraOverrides: CameraSettings
        // The photo as it is kept below the first one, with the id, text and border it had before it joined, which
        // it gets back when it leaves. Nil for the first photo, whose own became the entry's.
        var kept: Photo?
    }

    private var imageParts: [ImagePart] {
        let first = ImagePart(url: url, crop: crop, cameraOverrides: cameraOverrides, kept: nil)
        return [first] + stacked.map { ImagePart(url: $0.url, crop: $0.crop, cameraOverrides: $0.cameraOverrides, kept: $0) }
    }

    private mutating func setParts(_ parts: [ImagePart], boxes placed: [CanvasBox]) {
        guard let first = parts.first else { return }
        url = first.url
        crop = first.crop
        cameraOverrides = first.cameraOverrides
        // A photo that becomes the first one leaves what it kept behind, and the photo that was first takes that
        // over, so no two photos ever share an id.
        let leftBehind = first.kept
        stacked = parts.dropFirst().map { part in
            var photo = part.kept ?? leftBehind ?? Photo(url: part.url)
            photo.url = part.url
            photo.crop = part.crop
            photo.cameraOverrides = part.cameraOverrides
            return photo
        }
        boxes = placed
    }
}

/// A canvas laid out as a grid: every photo in a cell of the same size, filled row by row, slide by slide.
public enum CanvasGrid {
    public static let defaultSpacing = 0.06
    // At 0 the photos touch each other and the slide edges. Wider than this leaves little room for photos.
    public static let spacingRange = 0.0...0.15
    // A new grid gets this many photos on each slide.
    static let photosPerSlide = 4

    static func clamped(_ spacing: Double) -> Double {
        min(max(spacing.isFinite ? spacing : defaultSpacing, spacingRange.lowerBound), spacingRange.upperBound)
    }

    /// The slides a new grid of `photoCount` photos starts with.
    static func slideCount(photoCount: Int) -> Int {
        min(max((photoCount + photosPerSlide - 1) / photosPerSlide, 1), Photo.maxCanvasSlides)
    }

    /// One box per photo. Every slide gets the same rows and columns, as few as hold its share of the photos, in
    /// the mix that suits the slide's shape: a portrait slide gets more rows than columns. `spacing` is the space
    /// around and between the photos, in slide widths, and `slideRatio` makes it the same above and below.
    public static func boxes(photoCount: Int, slideCount: Int, slideRatio: Double, spacing: Double) -> [CanvasBox] {
        let slides = max(slideCount, 1)
        let perSlide = max((photoCount + slides - 1) / slides, 1)
        let columns = min(max(Int((Double(perSlide) * slideRatio).squareRoot().rounded()), 1), perSlide)
        let rows = (perSlide + columns - 1) / columns

        // Many photos at a wide spacing would leave cells smaller than a box may be, or none at all, so the spacing
        // gives way first.
        let gapX = min(clamped(spacing), max((1 - Double(columns) * CanvasBox.minimumSide) / Double(columns + 1), 0))
        let gapY = min(gapX * slideRatio, max((1 - Double(rows) * CanvasBox.minimumSide) / Double(rows + 1), 0))
        let width = (1 - Double(columns + 1) * gapX) / Double(columns)
        let height = (1 - Double(rows + 1) * gapY) / Double(rows)

        return (0..<photoCount).map { index in
            let slide = index / (rows * columns)
            let cell = index % (rows * columns)
            return CanvasBox(
                x: Double(slide) + gapX + Double(cell % columns) * (width + gapX), y: gapY + Double(cell / columns) * (height + gapY),
                width: width, height: height
            )
        }
    }
}
