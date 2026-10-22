import AppKit
import AutopostCore
import SwiftUI

/// Export settings are shared by all posts; the frame is per post.
struct ExportInspectorSection: View {
    let postID: Post.ID

    @Environment(LibraryStore.self) private var store
    @Environment(ExportController.self) private var exporter

    var body: some View {
        @Bindable var store = store
        let settings = $store.library.export

        Section("Export") {
            Picker("Size", selection: settings.size) {
                ForEach(ExportSize.allCases) { Text($0.label).tag($0) }
            }
            LabeledContent("Quality") {
                Slider(value: settings.quality, in: 0.6...1)
                SliderValueField(value: settings.quality, range: 0.6...1, scale: 100, width: 36)
            }
            Toggle("Output sharpening", isOn: settings.isSharpening)
            Toggle("Keep camera metadata", isOn: settings.keepsMetadata)
            Toggle("Remove location", isOn: settings.stripsLocation)
                .disabled(!settings.wrappedValue.keepsMetadata)
            Toggle("Show in Finder when done", isOn: settings.revealsInFinder)
            LabeledContent("Folder") {
                Text(settings.wrappedValue.destination.lastPathComponent)
                    .lineLimit(1).truncationMode(.middle)
                Button("Choose…") { chooseDestination(settings) }
            }
        }

        Section {
            if let progress = exporter.progress[postID] {
                ProgressView(value: progress) { Text("Exporting…") }
            } else {
                Text(summary).font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button("Export Post") { exporter.export(postID, in: store) }
                        .buttonStyle(.borderedProminent)
                    Button("AirDrop", systemImage: "dot.radiowaves.left.and.right") { exporter.export(postID, in: store, sendsViaAirDrop: true) }
                        .help("Export, then send the photos to your phone with AirDrop")
                }
                .disabled(store.post(postID)?.photos.isEmpty ?? true)
            }
        }
    }

    /// "6 photos → 1080 × 1350 JPEG, quality 92".
    private var summary: String {
        guard let post = store.post(postID) else { return "" }
        let settings = store.library.export
        let count = post.photos.count == 1 ? "1 photo" : "\(post.photos.count) photos"
        let size: String
        if let width = settings.size.fixedWidth, let ratio = post.frame.ratioValue {
            size = "\(width) × \(Int((Double(width) / ratio).rounded()))"
        } else {
            size = settings.size.fixedWidth.map { "\($0) px wide" } ?? "full size"
        }
        return "\(count) → \(size) JPEG, quality \(Int((settings.quality * 100).rounded()))"
    }

    private func chooseDestination(_ settings: Binding<ExportSettings>) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = settings.wrappedValue.destination
        panel.prompt = "Export Here"
        if panel.runModal() == .OK, let url = panel.url {
            settings.wrappedValue.destination = url
        }
    }
}
