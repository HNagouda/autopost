import CoreGraphics

/// Where a dragged text box likes to land: a 12-column grid plus the lines that matter on a framed photo,
/// such as the photo's edges and the middle of the border under it.
public enum TextSnapping {
    public static let gridDivisions = 12
    // How close, as a fraction of the canvas, a box must come before it snaps.
    public static let threshold = 0.015

    public struct Result: Equatable {
        // In canvas fractions.
        public var point: CGPoint
        public var xGuide: Double?
        public var yGuide: Double?

        public init(point: CGPoint, xGuide: Double? = nil, yGuide: Double? = nil) {
            self.point = point
            self.xGuide = xGuide
            self.yGuide = yGuide
        }
    }

    /// `point` and the result are in canvas fractions, 0 to 1 on each axis.
    public static func snap(_ point: CGPoint, layout: FrameLayout) -> Result {
        let size = layout.canvasSize
        let photo = layout.imageRect
        let grid = (0...gridDivisions).map { Double($0) / Double(gridDivisions) }

        let xLines = grid + [photo.minX, photo.midX, photo.maxX].map { $0 / size.width }
        let yLines = grid + [
            photo.minY, photo.midY, photo.maxY,
            photo.minY / 2,
            (photo.maxY + size.height) / 2,
        ].map { $0 / size.height }

        let x = nearest(to: point.x, in: xLines)
        let y = nearest(to: point.y, in: yLines)
        return Result(point: CGPoint(x: x ?? point.x, y: y ?? point.y), xGuide: x, yGuide: y)
    }

    private static func nearest(to value: Double, in lines: [Double]) -> Double? {
        let closest = lines.min { abs($0 - value) < abs($1 - value) }
        guard let closest, abs(closest - value) <= threshold else { return nil }
        return closest
    }
}
