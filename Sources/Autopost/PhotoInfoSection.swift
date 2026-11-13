import AppKit
import AutopostCore
import SwiftUI

/// What the open photo's file says about itself: size, when and where it was taken, and with what. Read only.
struct PhotoInfoSection: View {
    let photo: Photo

    @Environment(ThumbnailStore.self) private var thumbnails
    @State private var info: PhotoInfo?
    @State private var isUnreadable = false

    var body: some View {
        Section {
            if let info {
                rows(info)
            } else if isUnreadable {
                Text("Could not read this file.").foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.small)
            }
        } header: {
            Text(photo.isStack ? "Info for the top photo" : photo.isCanvas ? "Info for the first photo" : "Info")
        }
        // Reading the metadata touches the disk, which for a photo on a slow drive is worth keeping off the main thread.
        .task(id: photo.url) {
            let url = photo.url
            info = nil
            isUnreadable = false
            do {
                info = try await Task.detached { try PhotoInfo(url: url) }.value
            } catch {
                NSLog("Autopost: could not read metadata of %@: %@", url.path, error.localizedDescription)
                isUnreadable = true
            }
        }
    }

    @ViewBuilder
    private func rows(_ info: PhotoInfo) -> some View {
        LabeledContent("File", value: photo.url.lastPathComponent)
        LabeledContent("Size") {
            Text("\(Int(info.pixelSize.width)) × \(Int(info.pixelSize.height))  ·  \(info.megapixels.formatted(.number.precision(.fractionLength(1)))) MP")
        }
        LabeledContent("Aspect ratio", value: info.ratioLabel)
        if let fileSize = info.fileSize {
            LabeledContent("File size", value: Int64(fileSize).formatted(.byteCount(style: .file)))
        }
        if let taken = info.takenLabel {
            LabeledContent("Taken", value: taken)
        }
        if let camera = info.camera {
            LabeledContent("Camera", value: camera)
        }
        if let lens = info.lens {
            LabeledContent("Lens", value: lens)
        }
        if let exposure = exposure {
            LabeledContent("Exposure", value: exposure)
        }
        if let place = info.place {
            LabeledContent("Place", value: place)
        }
        if let latitude = info.latitude, let longitude = info.longitude {
            LabeledContent("Location") {
                Text(Self.coordinateLabel(latitude: latitude, longitude: longitude))
                Button("Show in Maps", systemImage: "map") { Self.openInMaps(latitude: latitude, longitude: longitude) }
                    .labelStyle(.iconOnly).buttonStyle(.borderless)
                    .help("Open this spot in Maps")
            }
        }
    }

    /// "35mm  ·  ƒ/2  ·  1/250s  ·  ISO 100", straight from the file, before any settings typed for the caption.
    private var exposure: String? {
        var settings = thumbnails.thumbnail(for: photo.url)?.exif ?? CameraSettings()
        settings.camera = nil
        return settings.line
    }

    /// 46.3625, 14.0936 -> "46.3625° N, 14.0936° E".
    private static func coordinateLabel(latitude: Double, longitude: Double) -> String {
        let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(4))
        let north = "\(abs(latitude).formatted(format))° \(latitude < 0 ? "S" : "N")"
        let east = "\(abs(longitude).formatted(format))° \(longitude < 0 ? "W" : "E")"
        return "\(north), \(east)"
    }

    private static func openInMaps(latitude: Double, longitude: Double) {
        guard let url = URL(string: "https://maps.apple.com/?ll=\(latitude),\(longitude)&q=Photo") else { return }
        NSWorkspace.shared.open(url)
    }
}
