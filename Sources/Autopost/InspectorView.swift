import AutopostCore
import SwiftUI

/// Frame settings for the selected post. One frame per post, because a carousel crops every slide to the first one's ratio.
struct InspectorView: View {
    let postID: Post.ID

    @Environment(LibraryStore.self) private var store
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system
    @State private var isNamingPreset = false
    @State private var presetName = ""

    // Off-white and pale grey suit warm film scans better than pure white.
    private static let swatches: [(String, FrameColor)] = [
        ("White", .white),
        ("Paper", FrameColor(red: 0.98, green: 0.97, blue: 0.94)),
        ("Mist", FrameColor(red: 0.93, green: 0.93, blue: 0.93)),
        ("Charcoal", FrameColor(red: 0.12, green: 0.12, blue: 0.12)),
        ("Black", FrameColor(red: 0, green: 0, blue: 0)),
    ]

    var body: some View {
        let frame = store.frameBinding(for: postID)

        Form {
            Section("Aspect ratio") {
                RatioPicker(frame: frame)
                if frame.wrappedValue.ratio == .custom {
                    HStack {
                        TextField("Width", value: frame.customRatioWidth, format: .number)
                        Text(":")
                        TextField("Height", value: frame.customRatioHeight, format: .number)
                    }
                }
            }

            Section("Border") {
                LabeledContent("Size") {
                    Slider(value: frame.borderPercent, in: 0...FrameLayout.maxBorderPercent)
                    Text("\(frame.wrappedValue.borderPercent, format: .number.precision(.fractionLength(1)))%")
                        .monospacedDigit().frame(width: 44, alignment: .trailing)
                }
                LabeledContent("Position") {
                    Slider(value: frame.verticalOffset, in: -1...1) {
                        Text("Position")
                    } minimumValueLabel: {
                        Image(systemName: "arrow.up.to.line").imageScale(.small)
                    } maximumValueLabel: {
                        Image(systemName: "arrow.down.to.line").imageScale(.small)
                    }
                    .labelsHidden()
                    Button("Center", systemImage: "arrow.counterclockwise") { frame.wrappedValue.verticalOffset = 0 }
                        .labelStyle(.iconOnly).buttonStyle(.borderless)
                }
                .disabled(frame.wrappedValue.ratio == .original)
                Toggle("Drop shadow", isOn: frame.hasShadow)
            }

            Section("Background") {
                Picker("Fill", selection: frame.background) {
                    Text("Color").tag(FrameBackground.color)
                    Text("Blurred photo").tag(FrameBackground.blur)
                }
                .pickerStyle(.segmented)
                if frame.wrappedValue.background == .color {
                    swatchRow(frame)
                }
            }

            Section("Caption") {
                Picker("Text", selection: frame.captionMode) {
                    Text("None").tag(CaptionMode.off)
                    Text("Camera settings").tag(CaptionMode.exif)
                    Text("Custom").tag(CaptionMode.custom)
                }
                if frame.wrappedValue.captionMode == .custom {
                    TextField("Kodak Gold 200 · Monterey", text: frame.captionText)
                }
            }

            Section("Presets") {
                presetsMenu(frame)
                Button("Use for New Posts") { store.library.defaultFrame = frame.wrappedValue }
            }

            ExportInspectorSection(postID: postID)
        }
        .formStyle(.grouped)
        .amoledBackground(theme)
        .alert("Save Preset", isPresented: $isNamingPreset) {
            TextField("Name", text: $presetName)
            Button("Save") {
                if !presetName.isEmpty { store.savePreset(named: presetName, frame: frame.wrappedValue) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func swatchRow(_ frame: Binding<FrameSettings>) -> some View {
        HStack(spacing: 8) {
            ForEach(Self.swatches, id: \.0) { name, color in
                Swatch(color: color, isChosen: frame.wrappedValue.color == color)
                    .help(name)
                    .onTapGesture { frame.wrappedValue.color = color }
            }
            Spacer()
            ColorPicker("Custom color", selection: Binding(
                get: { Color(rgb: frame.wrappedValue.color) },
                set: { frame.wrappedValue.color = FrameColor($0) }
            ), supportsOpacity: false)
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }

    private func presetsMenu(_ frame: Binding<FrameSettings>) -> some View {
        Menu("Apply Preset") {
            ForEach(store.library.presets) { preset in
                Button(preset.name) { frame.wrappedValue = preset.frame }
            }
            if !store.library.presets.isEmpty {
                Divider()
                Menu("Delete Preset") {
                    ForEach(store.library.presets) { preset in
                        Button(preset.name, role: .destructive) { store.deletePreset(preset.id) }
                    }
                }
            }
            Button("Save Current Frame as Preset…") {
                presetName = ""
                isNamingPreset = true
            }
        }
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

/// Ratio choices drawn as little frames, so the shape is visible before reading the label.
private struct RatioPicker: View {
    @Binding var frame: FrameSettings

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            ForEach(AspectRatio.allCases) { ratio in
                let isChosen = frame.ratio == ratio
                Button { frame.ratio = ratio } label: {
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(lineWidth: 1.5)
                            .aspectRatio(ratio.fixedValue ?? (ratio == .custom ? 1.2 : 1.5), contentMode: .fit)
                            .frame(height: 22)
                        Text(ratio.label).font(.caption2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(isChosen ? Color.accentColor : .secondary)
                    .background(isChosen ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(ratio.detail)
            }
        }
    }
}
