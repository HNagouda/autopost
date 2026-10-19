import AppKit
import CoreGraphics

let CANVAS = 1024.0
// Apple's macOS icon grid: the body sits inset from the canvas so the shadow has room.
let BODY_SIZE = 824.0
let BODY_RADIUS = 185.0
let CARD_HEIGHT = 520.0
let CARD_WIDTH = CARD_HEIGHT * 4.0 / 5.0
let CARD_BORDER = 34.0
let CARD_RADIUS = 10.0

// Every file an .iconset must contain, as (point size, scale).
let ICONSET_SIZES: [(Int, Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]

func color(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) -> CGColor {
    CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

func linearGradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
}

func drawBody(_ context: CGContext) {
    let inset = (CANVAS - BODY_SIZE) / 2
    let rect = CGRect(x: inset, y: inset, width: BODY_SIZE, height: BODY_SIZE)
    let path = CGPath(roundedRect: rect, cornerWidth: BODY_RADIUS, cornerHeight: BODY_RADIUS, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0, 0, 0, 0.45))
    context.addPath(path)
    context.setFillColor(color(0.1, 0.09, 0.08))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(path)
    context.clip()
    let gradient = linearGradient([color(0.22, 0.19, 0.17), color(0.04, 0.035, 0.03)])
    context.drawLinearGradient(
        gradient, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: [])
    context.restoreGState()
}

func drawCard(_ context: CGContext) {
    let card = CGRect(
        x: (CANVAS - CARD_WIDTH) / 2, y: (CANVAS - CARD_HEIGHT) / 2, width: CARD_WIDTH, height: CARD_HEIGHT)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -14), blur: 36, color: color(0, 0, 0, 0.6))
    context.addPath(CGPath(roundedRect: card, cornerWidth: CARD_RADIUS, cornerHeight: CARD_RADIUS, transform: nil))
    context.setFillColor(color(0.98, 0.97, 0.95))
    context.fillPath()
    context.restoreGState()

    let photo = card.insetBy(dx: CARD_BORDER, dy: CARD_BORDER)
    context.saveGState()
    context.clip(to: photo)
    let sunset = linearGradient([color(1.0, 0.72, 0.3), color(0.86, 0.25, 0.45), color(0.12, 0.14, 0.42)])
    context.drawLinearGradient(
        sunset, start: CGPoint(x: 0, y: photo.minY), end: CGPoint(x: 0, y: photo.maxY), options: [])
    context.restoreGState()
}

func renderMaster() -> NSBitmapImageRep {
    let side = Int(CANVAS)
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!.cgContext
    drawBody(context)
    drawCard(context)
    return bitmap
}

func resized(_ master: NSBitmapImageRep, to pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    context.imageInterpolation = .high
    NSGraphicsContext.current = context
    master.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: swift make-icon.swift <out.iconset dir>\n".data(using: .utf8)!)
    exit(1)
}

let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let master = renderMaster()
for (points, scale) in ICONSET_SIZES {
    let suffix = scale == 2 ? "@2x" : ""
    let name = "icon_\(points)x\(points)\(suffix).png"
    try resized(master, to: points * scale).write(to: outDir.appendingPathComponent(name))
}
