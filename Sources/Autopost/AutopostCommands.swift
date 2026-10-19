import AppKit
import AutopostCore
import SwiftUI

struct AutopostCommands: Commands {
    let store: LibraryStore
    let exporter: ExportController
    let editor: EditorSession

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
            Divider()
            Button("Restore from Backup…") { openWindow(id: WindowID.backups) }
        }

        // Text fields keep normal copy and paste; elsewhere in the editor these act on the selected text box.
        CommandGroup(replacing: .pasteboard) {
            Button("Cut") {
                if isEditingText || !editor.copySelectedBox(in: store, postID: selectedPostID) {
                    forward(#selector(NSText.cut(_:)))
                } else {
                    editor.deleteSelectedBox(in: store, postID: selectedPostID)
                }
            }
            .keyboardShortcut("x")
            Button("Copy") {
                if isEditingText || !editor.copySelectedBox(in: store, postID: selectedPostID) {
                    forward(#selector(NSText.copy(_:)))
                }
            }
            .keyboardShortcut("c")
            Button("Paste") {
                if isEditingText || !editor.isOpen {
                    forward(#selector(NSText.paste(_:)))
                } else {
                    editor.paste(in: store, postID: selectedPostID)
                }
            }
            .keyboardShortcut("v")
            Button("Select All") { forward(#selector(NSText.selectAll(_:))) }
                .keyboardShortcut("a")
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
            Button("Add Text Box") {
                if let id = store.selectedPostID { editor.addTextBox(in: store, postID: id) }
            }
            .keyboardShortcut("t")
            .disabled(!editor.isOpen)
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

    // SwiftUI text fields and editors are backed by an NSText field editor while the cursor is in them.
    private var isEditingText: Bool {
        NSApp.keyWindow?.firstResponder is NSText
    }

    // Commands only run with a post selected in practice; the nil UUID matches nothing, so the box actions do nothing.
    private var selectedPostID: Post.ID {
        store.selectedPostID ?? UUID()
    }

    private func forward(_ action: Selector) {
        NSApp.sendAction(action, to: nil, from: nil)
    }

    private func exportSelected(sendsViaAirDrop: Bool) {
        guard let id = store.selectedPostID else { return }
        exporter.export(id, in: store, sendsViaAirDrop: sendsViaAirDrop)
    }
}
