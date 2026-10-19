import AutopostCore
import SwiftUI

/// A row of colour dots plus the system colour picker, used for frames and for text.
struct ColorSwatchRow: View {
    @Binding var color: FrameColor
    let swatches: [(String, FrameColor)]

    // Off-white and pale grey suit warm film scans better than pure white.
    static let frameColors: [(String, FrameColor)] = [
        ("White", .white),
        ("Paper", FrameColor(red: 0.98, green: 0.97, blue: 0.94)),
        ("Mist", FrameColor(red: 0.93, green: 0.93, blue: 0.93)),
        ("Charcoal", FrameColor(red: 0.12, green: 0.12, blue: 0.12)),
        ("Black", FrameColor(red: 0, green: 0, blue: 0)),
    ]

    static let textColors: [(String, FrameColor)] = [
        ("Ink", FrameColor(red: 0.2, green: 0.2, blue: 0.2)),
        ("Grey", FrameColor(red: 0.55, green: 0.55, blue: 0.55)),
        ("Black", FrameColor(red: 0, green: 0, blue: 0)),
        ("White", .white),
        ("Rust", FrameColor(red: 0.72, green: 0.33, blue: 0.2)),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(swatches, id: \.0) { name, swatch in
                Swatch(color: swatch, isChosen: color == swatch)
                    .help(name)
                    .onTapGesture { color = swatch }
            }
            Spacer()
            ColorPicker("Custom color", selection: Binding(
                get: { Color(rgb: color) },
                set: { color = FrameColor($0) }
            ), supportsOpacity: false)
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

private struct Swatch: View {
    let color: FrameColor
    let isChosen: Bool

    var body: some View {
        Circle()
            .fill(Color(rgb: color))
            .overlay { Circle().strokeBorder(Color.secondary.opacity(0.5), lineWidth: 0.5) }
            .overlay { Circle().strokeBorder(Color.accentColor, lineWidth: isChosen ? 2 : 0).padding(-3) }
            .frame(width: 20, height: 20)
    }
}
