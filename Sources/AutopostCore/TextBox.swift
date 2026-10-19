import CoreGraphics
import CoreText
import Foundation

public enum TextBoxAlignment: String, Codable, CaseIterable, Sendable {
    case leading
    case center
    case trailing
}

/// Free text placed anywhere on the framed canvas. Position and size are fractions of the canvas,
/// so a box sits in the same spot at 1080 px and at full resolution, and on every photo it is copied to.
public struct TextBox: Codable, Identifiable, Equatable, Sendable {
    // Stands for the macOS system font, which has no stable family name to look up.
    public static let systemFontFamily = "System"

    public var id = UUID()
    public var text = "Text"
    public var fontFamily = systemFontFamily
    // Font size as a fraction of the canvas width.
    public var size = 0.035
    public var isBold = false
    public var isItalic = false
    public var color = FrameColor(red: 0.2, green: 0.2, blue: 0.2)
    public var alignment: TextBoxAlignment = .center
    // Letter spacing as a fraction of the font size.
    public var tracking = 0.0
    // x is the left edge, centre or right edge depending on alignment; y is the vertical centre.
    public var x = 0.5
    public var y = 0.94

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = TextBox()
        id = try container.decode(.id, default: UUID())
        text = try container.decode(.text, default: defaults.text)
        fontFamily = try container.decode(.fontFamily, default: defaults.fontFamily)
        size = try container.decode(.size, default: defaults.size)
        isBold = try container.decode(.isBold, default: defaults.isBold)
        isItalic = try container.decode(.isItalic, default: defaults.isItalic)
        color = try container.decode(.color, default: defaults.color)
        alignment = try container.decode(.alignment, default: defaults.alignment)
        tracking = try container.decode(.tracking, default: defaults.tracking)
        x = try container.decode(.x, default: defaults.x)
        y = try container.decode(.y, default: defaults.y)
    }

    /// The same box with a new identity, for pasting or copying onto another photo.
    public func duplicated() -> TextBox {
        var copy = self
        copy.id = UUID()
        return copy
    }
}

/// Lays out and draws text boxes with Core Text. The editor, the grid and the exporter all draw through here.
public enum TextBoxRenderer {
    // Slant for families without an italic face, about the angle of a real oblique.
    static let syntheticItalicSkew = 0.21
    // Text is always laid out on a canvas this wide and then scaled. Fonts like SF switch to a narrower
    // optical size as they grow, so laying out at the real size would make the export wider or narrower than the preview.
    static let referenceWidth = 1000.0

    struct PlacedLine {
        var line: CTLine
        // Baseline start, top-left origin.
        var origin: CGPoint
        var width: Double
    }

    public static func font(for box: TextBox, canvasWidth: Double) -> CTFont {
        let size = max(box.size * canvasWidth, 1)
        let base = box.fontFamily == TextBox.systemFontFamily
            ? CTFontCreateUIFontForLanguage(.system, size, nil)!
            : CTFontCreateWithName(box.fontFamily as CFString, size, nil)

        var traits: CTFontSymbolicTraits = []
        if box.isBold { traits.insert(.traitBold) }
        if box.isItalic { traits.insert(.traitItalic) }
        if traits.isEmpty { return base }
        if let styled = CTFontCreateCopyWithSymbolicTraits(base, size, nil, traits, traits) { return styled }

        // Not every family has a bold italic or an italic at all: keep the weight and slant the letters instead.
        let bold = box.isBold ? CTFontCreateCopyWithSymbolicTraits(base, size, nil, .traitBold, .traitBold) ?? base : base
        guard box.isItalic else { return bold }
        var skew = CGAffineTransform(a: 1, b: 0, c: syntheticItalicSkew, d: 1, tx: 0, ty: 0)
        return CTFontCreateCopyWithAttributes(bold, size, &skew, nil)
    }

    private static func referenceSize(for canvasSize: CGSize) -> CGSize {
        CGSize(width: referenceWidth, height: canvasSize.height / canvasSize.width * referenceWidth)
    }

    /// Lines laid out on the reference canvas.
    static func placedLines(for box: TextBox, canvasSize: CGSize) -> [PlacedLine] {
        let canvasSize = referenceSize(for: canvasSize)
        let font = font(for: box, canvasWidth: canvasSize.width)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(
                srgbRed: box.color.red, green: box.color.green, blue: box.color.blue, alpha: 1
            ),
            NSAttributedString.Key(kCTKernAttributeName as String): box.tracking * CTFontGetSize(font),
        ]

        let ascent = CTFontGetAscent(font)
        let lineHeight = ascent + CTFontGetDescent(font) + CTFontGetLeading(font)
        let texts = box.text.components(separatedBy: .newlines)
        let top = box.y * canvasSize.height - Double(texts.count) * lineHeight / 2
        let anchor = box.x * canvasSize.width

        return texts.enumerated().map { index, text in
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
            let width = CTLineGetTypographicBounds(line, nil, nil, nil)
            let x = switch box.alignment {
            case .leading: anchor
            case .center: anchor - width / 2
            case .trailing: anchor - width
            }
            return PlacedLine(line: line, origin: CGPoint(x: x, y: top + ascent + Double(index) * lineHeight), width: width)
        }
    }

    /// The box's outline on the canvas, top-left origin, for selecting and dragging it.
    public static func bounds(for box: TextBox, canvasSize: CGSize) -> CGRect {
        let font = font(for: box, canvasWidth: referenceWidth)
        let lines = placedLines(for: box, canvasSize: canvasSize)
        let ascent = CTFontGetAscent(font)
        let lineHeight = ascent + CTFontGetDescent(font) + CTFontGetLeading(font)
        let minX = lines.map(\.origin.x).min() ?? box.x * referenceWidth
        let maxX = lines.map { $0.origin.x + $0.width }.max() ?? minX
        let top = (lines.first?.origin.y ?? 0) - ascent

        // A box with no visible text still needs something to grab.
        let reference = CGRect(x: minX, y: top, width: max(maxX - minX, lineHeight / 2), height: Double(lines.count) * lineHeight)
        let scale = canvasSize.width / referenceWidth
        return reference.applying(CGAffineTransform(scaleX: scale, y: scale))
    }

    /// Draws into a context whose origin is bottom left, as Core Graphics bitmaps are.
    public static func draw(_ boxes: [TextBox], in context: CGContext, canvasSize: CGSize) {
        let reference = referenceSize(for: canvasSize)
        context.saveGState()
        context.scaleBy(x: canvasSize.width / referenceWidth, y: canvasSize.width / referenceWidth)
        context.textMatrix = .identity
        for box in boxes {
            for placed in placedLines(for: box, canvasSize: canvasSize) {
                context.textPosition = CGPoint(x: placed.origin.x, y: reference.height - placed.origin.y)
                CTLineDraw(placed.line, context)
            }
        }
        context.restoreGState()
    }
}
