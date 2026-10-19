import AutopostCore
import SwiftUI

struct AutopostCommands: Commands {
    let store: LibraryStore
    let exporter: ExportController

    @Environment(\.openWindow) private var openWindow
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Post") { store.createPost() }
                .keyboardShortcut("n")
            Button("Add Photos…") { store.addPhotosToSelectedPost(FileImport.choosePhotos(allowsFolders: false)) }
                .keyboardShortcut("o")
            Button("Create Posts from Folders…") { store.createPosts(from: FileImport.choosePhotos(allowsFolders: true)) }
                .keyboardShortcut("o", modifiers: [.command, .shift])
        }

        CommandMenu("Post") {
            Button("Export Post") { exportSelected(sendsViaAirDrop: false) }
                .keyboardShortcut("e")
            Button("Export and AirDrop…") { exportSelected(sendsViaAirDrop: true) }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            Button("Show Exports in Finder") {
                if let post = store.selectedPost { exporter.revealExports(of: post, settings: store.library.export) }
            }
            Divider()
            Button("Phone Preview") { openWindow(id: WindowID.phone) }
                .keyboardShortcut("p", modifiers: [.command, .option])
        }

        CommandGroup(after: .toolbar) {
            Picker("Appearance", selection: $theme) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
            }
        }
    }

    private func exportSelected(sendsViaAirDrop: Bool) {
        guard let id = store.selectedPostID else { return }
        exporter.export(id, in: store, sendsViaAirDrop: sendsViaAirDrop)
    }
}
