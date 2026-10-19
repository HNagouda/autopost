import AutopostCore
import SwiftUI

/// Ratio choices drawn as little frames, so the shape is visible before reading the label.
struct RatioPicker: View {
    @Binding var frame: FrameSettings

    @Environment(LibraryStore.self) private var store

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        let saved = store.library.savedRatios
        let isSavedChosen = saved.contains { frame.uses($0) }

        VStack(alignment: .leading, spacing: 8) {
            group("Portrait", AspectRatio.portrait)
            group("Square", AspectRatio.squareAndOriginal + [.custom], isCustomChosen: frame.ratio == .custom && !isSavedChosen)
            group("Landscape", AspectRatio.landscape)
            if !saved.isEmpty {
                heading("Saved")
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

    private func group(_ title: String, _ ratios: [AspectRatio], isCustomChosen: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            heading(title)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(ratios) { ratio in
                    let isChosen = ratio == .custom ? isCustomChosen : frame.ratio == ratio
                    // Original and custom have no fixed shape; these stand-ins just hint at it.
                    let shape = ratio.fixedValue ?? (ratio == .custom ? 1.2 : 1.5)
                    RatioTile(label: ratio.label, shape: shape, isChosen: isChosen) { frame.ratio = ratio }
                        .help(ratio.detail)
                }
            }
        }
    }

    private func heading(_ title: String) -> some View {
        Text(title).font(.caption).foregroundStyle(.secondary)
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
