import AutopostCore
import SwiftUI

/// Ratio choices drawn as little frames, so the shape is visible before reading the label.
struct RatioPicker: View {
    @Binding var frame: FrameSettings

    @Environment(LibraryStore.self) private var store

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    // Every built-in ratio in picker order: three full rows of four, portrait and square first, then landscape.
    private static let order: [AspectRatio] = [
        .portrait4x5, .portrait3x4, .story9x16, .square,
        .landscape5x4, .landscape4x3, .landscape3x2, .landscape191x1,
        .landscape16x9, .landscape2x1, .original, .custom,
    ]

    var body: some View {
        let saved = store.library.savedRatios
        let isSavedChosen = saved.contains { frame.uses($0) }

        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Self.order) { ratio in
                    let isChosen = ratio == .custom ? frame.ratio == .custom && !isSavedChosen : frame.ratio == ratio
                    // Original and custom have no fixed shape; these stand-ins just hint at it.
                    let shape = ratio.fixedValue ?? (ratio == .custom ? 1.2 : 1.5)
                    RatioTile(label: ratio.label, shape: shape, isChosen: isChosen) { frame.ratio = ratio }
                        .help(ratio.detail)
                }
            }
            if !saved.isEmpty {
                Text("Saved").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(saved) { ratio in
                        RatioTile(label: ratio.label, shape: ratio.width / ratio.height, isChosen: frame.uses(ratio)) {
                            frame.use(ratio)
                        }
                        .contextMenu {
                            Button("Delete Saved Ratio", role: .destructive) { store.deleteSavedRatio(ratio.id) }
                        }
                    }
                }
            }
        }
    }
}

private struct RatioTile: View {
    let label: String
    let shape: Double
    let isChosen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(lineWidth: 1.5)
                    .aspectRatio(shape, contentMode: .fit)
                    .frame(width: 44, height: 22)
                Text(label).font(.caption2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(isChosen ? Color.accentColor : .secondary)
            .background(isChosen ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
