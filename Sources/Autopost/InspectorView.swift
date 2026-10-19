import AutopostCore
import SwiftUI

/// Frame settings for the selected post. One frame per post, because a carousel crops every slide to the first one's ratio.
struct InspectorView: View {
    let postID: Post.ID

    @Environment(LibraryStore.self) private var store
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system
    @State private var isNamingPreset = false
    @State private var presetName = ""

    var body: some View {
        let frame = store.frameBinding(for: postID)

        Form {
            Section {
                RatioPicker(frame: frame)
                if frame.wrappedValue.ratio == .custom {
                    HStack {
                        TextField("Width", value: frame.customRatioWidth, format: .number)
                        Text(":")
                        TextField("Height", value: frame.customRatioHeight, format: .number)
                        Button("Save") {
                            store.saveRatio(width: frame.wrappedValue.customRatioWidth, height: frame.wrappedValue.customRatioHeight)
                        }
                        .disabled(store.library.savedRatios.contains { frame.wrappedValue.uses($0) })
                        .help("Keep this ratio next to the built-in ones")
                    }
                }
            } header: {
                Text("Aspect ratio")
            } footer: {
                if let ratio = frame.wrappedValue.ratioValue, !InstagramFeed.fits(ratio), frame.wrappedValue.ratio != .story9x16 {
                    Label("Instagram crops feed posts to between 4:5 and 1.91:1, so this ratio gets cropped there.", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
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
                    ColorSwatchRow(color: frame.color, swatches: ColorSwatchRow.frameColors)
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
