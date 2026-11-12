import Foundation

/// Where a photo moved or resized on a canvas likes to land: slide edges and middles, the margin inside each slide,
/// and the edges of the other photos.
public enum CanvasSnapping {
    public struct Lines: Equatable, Sendable {
        // In slide widths.
        public var x: [Double]
        // In fractions of the slide height.
        public var y: [Double]
    }

    public struct Result: Equatable, Sendable {
        public var box: CanvasBox
        public var xGuide: Double?
        public var yGuide: Double?

        public init(box: CanvasBox, xGuide: Double? = nil, yGuide: Double? = nil) {
            self.box = box
            self.xGuide = xGuide
            self.yGuide = yGuide
        }
    }

    // Which edges of a box a drag moves: -1 the left or top edge, 1 the right or bottom edge, 0 neither.
    public struct Handle: Hashable, Sendable {
        public var horizontal: Int
        public var vertical: Int

        public init(horizontal: Int, vertical: Int) {
            self.horizontal = horizontal
            self.vertical = vertical
        }

        /// The four corners and the four sides.
        public static let all: [Handle] = [-1, 0, 1].flatMap { vertical in
            [-1, 0, 1].compactMap { horizontal in
                horizontal == 0 && vertical == 0 ? nil : Handle(horizontal: horizontal, vertical: vertical)
            }
        }
    }

    /// `marginX` is in slide widths and `marginY` in fractions of the slide height.
    public static func lines(slideCount: Int, marginX: Double, marginY: Double, others: [CanvasBox]) -> Lines {
        let slides = (0..<slideCount).flatMap { slide in
            [0, marginX, 0.5, 1 - marginX, 1].map { Double(slide) + $0 }
        }
        return Lines(
            x: slides + others.flatMap { [$0.x, $0.midX, $0.maxX] },
            y: [0, marginY, 0.5, 1 - marginY, 1] + others.flatMap { [$0.y, $0.midY, $0.maxY] }
        )
    }

    /// The box moved so that its nearest edge or middle sits on a line, on each axis that has one within reach.
    public static func moved(_ box: CanvasBox, lines: Lines, thresholdX: Double, thresholdY: Double) -> Result {
        var result = Result(box: box)
        if let snap = nearest(to: [box.x, box.midX, box.maxX], in: lines.x, within: thresholdX) {
            result.box.x += snap.shift
            result.xGuide = snap.line
        }
        if let snap = nearest(to: [box.y, box.midY, box.maxY], in: lines.y, within: thresholdY) {
            result.box.y += snap.shift
            result.yGuide = snap.line
        }
        return result
    }

    /// The box with the edges `handle` holds moved by the drag, snapped to a line within reach, and never smaller
    /// than the smallest box.
    public static func resized(
        _ box: CanvasBox, handle: Handle, byX deltaX: Double, y deltaY: Double, lines: Lines?, thresholdX: Double, thresholdY: Double
    ) -> Result {
        var minX = box.x, maxX = box.maxX, minY = box.y, maxY = box.maxY
        var result = Result(box: box)

        if handle.horizontal < 0 {
            minX = snapped(minX + deltaX, in: lines?.x, within: thresholdX, guide: &result.xGuide)
            minX = min(minX, maxX - CanvasBox.minimumSide)
        } else if handle.horizontal > 0 {
            maxX = snapped(maxX + deltaX, in: lines?.x, within: thresholdX, guide: &result.xGuide)
            maxX = max(maxX, minX + CanvasBox.minimumSide)
        }
        if handle.vertical < 0 {
            minY = snapped(minY + deltaY, in: lines?.y, within: thresholdY, guide: &result.yGuide)
            minY = min(minY, maxY - CanvasBox.minimumSide)
        } else if handle.vertical > 0 {
            maxY = snapped(maxY + deltaY, in: lines?.y, within: thresholdY, guide: &result.yGuide)
            maxY = max(maxY, minY + CanvasBox.minimumSide)
        }

        // Only the axis that was dragged is worked out anew, so the other keeps its exact size.
        if handle.horizontal != 0 {
            result.box.x = minX
            result.box.width = maxX - minX
        }
        if handle.vertical != 0 {
            result.box.y = minY
            result.box.height = maxY - minY
        }
        return result
    }

    private static func snapped(_ value: Double, in lines: [Double]?, within threshold: Double, guide: inout Double?) -> Double {
        guard let lines, let snap = nearest(to: [value], in: lines, within: threshold) else { return value }
        guide = snap.line
        return snap.line
    }

    /// The smallest move that puts one of `values` on one of `lines`.
    private static func nearest(to values: [Double], in lines: [Double], within threshold: Double) -> (shift: Double, line: Double)? {
        var best: (shift: Double, line: Double)?
        for value in values {
            for line in lines where abs(line - value) <= threshold && abs(line - value) < abs(best?.shift ?? .infinity) {
                best = (line - value, line)
            }
        }
        return best
    }
}
