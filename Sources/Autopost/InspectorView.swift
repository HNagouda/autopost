import AutopostCore
import SwiftUI

/// Frame settings for the selected post. One frame per post, because a carousel crops every slide to the first one's ratio.
struct InspectorView: View {
    let postID: Post.ID

    @Environment(LibraryStore.self) private var store
    @Environment(ThumbnailStore.self) private var thumbnails
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
                        TextField("Width", value: frame.customRatioWidth, format: .number, prompt: Text("Width"))
                            .labelsHidden()
                        Text(":")
                        TextField("Height", value: frame.customRatioHeight, format: .number, prompt: Text("Height"))
                            .labelsHidden()
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
                    SliderValueField(value: frame.borderPercent, range: 0...FrameLayout.maxBorderPercent, fractionDigits: 1, unit: "%", width: 52)
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
                    // A bare title becomes the row's label in a grouped form, so the hint goes in the prompt.
                    TextField("Caption", text: frame.captionText, prompt: Text("Kodak Gold 200 · Monterey"))
                }
                if frame.wrappedValue.captionMode == .exif {
                    cameraNameFields()
                }
                if frame.wrappedValue.captionMode != .off {
                    TextStyleControls(
                        fontFamily: frame.captionFontFamily, size: frame.captionSize,
                        isBold: frame.captionIsBold, isItalic: frame.captionIsItalic, tracking: frame.captionTracking
                    )
                    Toggle("Automatic colour", isOn: Binding(
                        get: { frame.wrappedValue.captionColor == nil },
                        set: { isAutomatic in
                            frame.wrappedValue.captionColor = isAutomatic ? nil : frame.wrappedValue.automaticCaptionColor
                        }
                    ))
                    .help("Dark text on a light frame, light text on a dark frame or blurred photo")
                    if let color = frame.wrappedValue.captionColor {
                        ColorSwatchRow(
                            color: Binding(get: { color }, set: { frame.wrappedValue.captionColor = $0 }),
                            swatches: ColorSwatchRow.textColors
                        )
                    }
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

    /// One row per camera in this post, to print a friendlier name than the EXIF model. Names apply to every post.
    @ViewBuilder
    private func cameraNameFields() -> some View {
        let photos = store.post(postID)?.photos ?? []
        let models = Set(photos.compactMap { thumbnails.thumbnail(for: $0.url)?.exif.camera }).sorted()

        ForEach(models, id: \.self) { model in
            TextField(model, text: Binding(
                get: { store.library.cameraNames[model] ?? "" },
                set: { name in store.library.cameraNames[model] = name.isEmpty ? nil : name }
            ), prompt: Text(model))
        }
        if !models.isEmpty {
            Text("Rename a camera once and every photo from it prints the new name. Open a photo to change its own settings.")
                .font(.caption).foregroundStyle(.secondary)
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
