import CoreGraphics

/// Finds a plain border baked into a photo file, like the white margin some scanning and editing apps add, so the
/// crop can cut it off. Autopost draws its own border, and a baked-in one shows up as extra width on some sides.
public enum EdgeTrim {
    // How far a pixel may differ from the corner colour, per channel out of 255, and still count as border. JPEG
    // noise along a flat margin stays well inside this.
    private static let colorTolerance = 24
    // A row or column counts as border when this share of its pixels matches; a speck of dust does not stop it.
    private static let matchingShare = 0.98
    // A border wider than this is more likely a white sky than a margin, so the search stops here.
    private static let maxBorderShare = 0.25
    // Cut a little past the edge found, so no pale fringe of the margin is left on the photo.
    private static let fringeShare = 0.003

    /// The crop that removes the border, or nil when the photo has none.
    public static func crop(removingBorderOf image: CGImage) -> CropRect? {
        guard let pixels = Pixels(image) else { return nil }
        let corner = pixels.color(x: 0, y: 0)
        let maxColumns = Int(Double(pixels.width) * maxBorderShare)
        let maxRows = Int(Double(pixels.height) * maxBorderShare)

        // A side whose plain run never ends within the limit is a flat sky or wall reaching the edge, not a margin.
        let left = (0..<maxColumns).first { !pixels.isColumnBorder($0, color: corner) } ?? 0
        let right = (0..<maxColumns).first { !pixels.isColumnBorder(pixels.width - 1 - $0, color: corner) } ?? 0
        let top = (0..<maxRows).first { !pixels.isRowBorder($0, color: corner) } ?? 0
        let bottom = (0..<maxRows).first { !pixels.isRowBorder(pixels.height - 1 - $0, color: corner) } ?? 0
        guard max(left, right, top, bottom) > 0 else { return nil }

        let width = Double(pixels.width), height = Double(pixels.height)
        let minX = min(Double(left) / width + fringeShare, 1)
        let minY = min(Double(top) / height + fringeShare, 1)
        let maxX = max(1 - Double(right) / width - fringeShare, minX)
        let maxY = max(1 - Double(bottom) / height - fringeShare, minY)
        let crop = CropRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        return crop.isValid ? crop : nil
    }

    /// The image redrawn as plain 8-bit RGBA, which is quick to read pixel by pixel.
    private struct Pixels {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        init?(_ image: CGImage) {
            let width = image.width
            let height = image.height
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            let drawn = bytes.withUnsafeMutableBytes { buffer in
                guard let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else { return false }
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                return true
            }
            guard drawn, width > 0, height > 0 else { return nil }
            self.width = width
            self.height = height
            self.bytes = bytes
        }

        /// Red, green and blue of one pixel, counted from the top-left.
        func color(x: Int, y: Int) -> (Int, Int, Int) {
            let index = (y * width + x) * 4
            return (Int(bytes[index]), Int(bytes[index + 1]), Int(bytes[index + 2]))
        }

        func isRowBorder(_ y: Int, color: (Int, Int, Int)) -> Bool {
            let matching = (0..<width).count(where: { matches(self.color(x: $0, y: y), color) })
            return Double(matching) >= Double(width) * EdgeTrim.matchingShare
        }

        func isColumnBorder(_ x: Int, color: (Int, Int, Int)) -> Bool {
            let matching = (0..<height).count(where: { matches(self.color(x: x, y: $0), color) })
            return Double(matching) >= Double(height) * EdgeTrim.matchingShare
        }

        private func matches(_ a: (Int, Int, Int), _ b: (Int, Int, Int)) -> Bool {
            abs(a.0 - b.0) <= EdgeTrim.colorTolerance && abs(a.1 - b.1) <= EdgeTrim.colorTolerance && abs(a.2 - b.2) <= EdgeTrim.colorTolerance
        }
    }
}
