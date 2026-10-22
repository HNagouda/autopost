import CoreGraphics

/// The part of a photo that is kept, as fractions of the upright photo with a top-left origin.
///
/// Fractions rather than pixels, so the same crop fits the small preview, the large editor image and the full-size
/// export. The crop decides the photo's shape; the post's ratio still decides the canvas around it, so a square crop
/// inside a 4:5 post gets a taller border.
public struct CropRect: Codable, Equatable, Sendable {
    // Smallest side a crop can shrink to, as a fraction of the photo, so a handle can never collapse it to nothing.
    public static let minimumSide = 0.05
    public static let full = CropRect(x: 0, y: 0, width: 1, height: 1)

    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var isFull: Bool { self == .full }

    /// True when the crop is a real part of the photo: finite, inside it, and not smaller than `minimumSide`.
    public var isValid: Bool {
        let values = [x, y, width, height]
        // Allows for rounding in fractions written by an earlier drag.
        let tolerance = 0.000_001
        return values.allSatisfy(\.isFinite) && x >= 0 && y >= 0
            && width >= Self.minimumSide - tolerance && height >= Self.minimumSide - tolerance
            && x + width <= 1 + tolerance && y + height <= 1 + tolerance
    }

    public func pixelRect(in imageSize: CGSize) -> CGRect {
        CGRect(x: x * imageSize.width, y: y * imageSize.height, width: width * imageSize.width, height: height * imageSize.height)
    }

    /// The size the photo has once cropped.
    public func size(of imageSize: CGSize) -> CGSize {
        CGSize(width: width * imageSize.width, height: height * imageSize.height)
    }

    /// The crop slid by a fraction of the photo, stopping at the photo's edges.
    public func moved(byX dx: Double, y dy: Double) -> CropRect {
        var moved = self
        moved.x = min(max(x + dx, 0), 1 - width)
        moved.y = min(max(y + dy, 0), 1 - height)
        return moved
    }

    /// The crop with one handle dragged to `point`, a fraction of the photo.
    ///
    /// `shape` is the crop's width over height in pixels, to keep while resizing, or nil to resize freely.
    /// `imageAspect` is the whole photo's width over height in pixels, which turns that shape into fractions.
    public func resized(_ handle: CropHandle, to point: CGPoint, shape: Double?, imageAspect: Double) -> CropRect {
        guard let shape else { return resizedFreely(handle, to: point) }
        // Width over height measured in fractions of the photo rather than in pixels.
        let ratio = shape / imageAspect
        return handle.isCorner
            ? resizedCorner(handle, to: point, ratio: ratio)
            : resizedEdge(handle, to: point, ratio: ratio)
    }

    /// The largest crop of `shape` (width over height in pixels) that fits the photo, centred where this crop is.
    public func fitted(toShape shape: Double, imageAspect: Double) -> CropRect {
        let ratio = shape / imageAspect
        let newWidth = ratio >= 1 ? 1 : ratio
        let newHeight = ratio >= 1 ? 1 / ratio : 1
        let centered = CropRect(x: x + width / 2 - newWidth / 2, y: y + height / 2 - newHeight / 2, width: newWidth, height: newHeight)
        return centered.moved(byX: 0, y: 0)
    }

    private func resizedFreely(_ handle: CropHandle, to point: CGPoint) -> CropRect {
        var minX = x, minY = y, maxX = x + width, maxY = y + height
        if handle.movesLeft { minX = min(max(point.x, 0), maxX - Self.minimumSide) }
        if handle.movesRight { maxX = max(min(point.x, 1), minX + Self.minimumSide) }
        if handle.movesTop { minY = min(max(point.y, 0), maxY - Self.minimumSide) }
        if handle.movesBottom { maxY = max(min(point.y, 1), minY + Self.minimumSide) }
        return CropRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Grows or shrinks away from the opposite corner, which stays put.
    private func resizedCorner(_ handle: CropHandle, to point: CGPoint, ratio: Double) -> CropRect {
        let anchorX = handle.movesLeft ? x + width : x
        let anchorY = handle.movesTop ? y + height : y
        let roomX = handle.movesLeft ? anchorX : 1 - anchorX
        let roomY = handle.movesTop ? anchorY : 1 - anchorY

        // Follow whichever direction the pointer went further in, then shrink until it fits the photo. Distances
        // count toward the dragged side, so dragging past the opposite corner stops at the smallest crop.
        let towardX = handle.movesLeft ? anchorX - point.x : point.x - anchorX
        let towardY = handle.movesTop ? anchorY - point.y : point.y - anchorY
        let wanted = max(towardX, towardY * ratio)
        let newWidth = max(min(wanted, roomX, roomY * ratio), Self.minimumSide * max(1, ratio))
        let newHeight = newWidth / ratio

        return CropRect(
            x: handle.movesLeft ? anchorX - newWidth : anchorX,
            y: handle.movesTop ? anchorY - newHeight : anchorY,
            width: newWidth,
            height: newHeight
        )
    }

    /// Moves the dragged edge and grows the other direction evenly about the crop's centre line.
    private func resizedEdge(_ handle: CropHandle, to point: CGPoint, ratio: Double) -> CropRect {
        let midX = x + width / 2
        let midY = y + height / 2

        if handle == .left || handle == .right {
            let anchorX = handle == .left ? x + width : x
            let roomX = handle == .left ? anchorX : 1 - anchorX
            let roomY = 2 * min(midY, 1 - midY)
            let toward = handle == .left ? anchorX - point.x : point.x - anchorX
            let newWidth = max(min(toward, roomX, roomY * ratio), Self.minimumSide * max(1, ratio))
            let newHeight = newWidth / ratio
            return CropRect(x: handle == .left ? anchorX - newWidth : anchorX, y: midY - newHeight / 2, width: newWidth, height: newHeight)
        }

        let anchorY = handle == .top ? y + height : y
        let roomY = handle == .top ? anchorY : 1 - anchorY
        let roomX = 2 * min(midX, 1 - midX)
        let toward = handle == .top ? anchorY - point.y : point.y - anchorY
        let newHeight = max(min(toward, roomY, roomX / ratio), Self.minimumSide * max(1, 1 / ratio))
        let newWidth = newHeight * ratio
        return CropRect(x: midX - newWidth / 2, y: handle == .top ? anchorY - newHeight : anchorY, width: newWidth, height: newHeight)
    }
}

/// The corners and edge midpoints of a crop that can be dragged.
public enum CropHandle: CaseIterable, Sendable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    public var isCorner: Bool { [.topLeft, .topRight, .bottomRight, .bottomLeft].contains(self) }
    var movesLeft: Bool { [.topLeft, .left, .bottomLeft].contains(self) }
    var movesRight: Bool { [.topRight, .right, .bottomRight].contains(self) }
    var movesTop: Bool { [.topLeft, .top, .topRight].contains(self) }
    var movesBottom: Bool { [.bottomLeft, .bottom, .bottomRight].contains(self) }

    /// Where the handle sits on the crop, as fractions of the crop's width and height.
    public var anchor: CGPoint {
        CGPoint(
            x: movesLeft ? 0 : movesRight ? 1 : 0.5,
            y: movesTop ? 0 : movesBottom ? 1 : 0.5
        )
    }
}

extension CGImage {
    /// The kept part of the image. Cropping a CGImage shares its pixels, so this is cheap enough for every redraw.
    public func cropped(to crop: CropRect) -> CGImage? {
        guard !crop.isFull else { return self }
        return cropping(to: crop.pixelRect(in: CGSize(width: width, height: height)).integral)
    }
}
