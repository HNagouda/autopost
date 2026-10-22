import AppKit
import AutopostCore
import SwiftUI

struct AutopostCommands: Commands {
    let store: LibraryStore
    let exporter: ExportController
    let editor: EditorSession

    @Environment(\.openWindow) private var openWindow
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system
    @AppStorage(PhonePreviewView.shownKey) private var isPhoneShown = false

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Post") { store.createPost(startsRenaming: true) }
                .keyboardShortcut("n")
            Button("Add Photos…") { store.addPhotosToSelectedPost(FileImport.choosePhotos(allowsFolders: false)) }
                .keyboardShortcut("o")
            Button("Create Posts from Folders…") { store.createPosts(from: FileImport.choosePhotos(allowsFolders: true)) }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            Divider()
            Button("Restore from Backup…") { openWindow(id: WindowID.backups) }
        }

        // While typing in a text field, ⌘Z undoes the typing; everywhere else it undoes the last change to the library.
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                if isEditingText { forward(Selector(("undo:"))) } else { store.undo() }
            }
            .keyboardShortcut("z")
            Button("Redo") {
                if isEditingText { forward(Selector(("redo:"))) } else { store.redo() }
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
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
            Button("Delete") { deleteSelection() }
                .keyboardShortcut(.delete, modifiers: .command)
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
            Button(isPhoneShown ? "Hide Phone Preview" : "Show Phone Preview") {
                withAnimation(PhonePreviewView.panelAnimation) { isPhoneShown.toggle() }
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
        }

        CommandGroup(replacing: .help) {
            Button("Autopost Tour") { openWindow(id: WindowID.tour) }
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

    /// ⌘⌫ removes what is selected in the main window, the way Delete does. In a text field it keeps its usual
    /// meaning, deleting to the start of the line.
    private func deleteSelection() {
        if isEditingText {
            forward(#selector(NSResponder.deleteToBeginningOfLine(_:)))
        } else if !WindowID.isMain(NSApp.keyWindow) || editor.isCropping {
            return
        } else if editor.isOpen {
            editor.deleteSelection(in: store, postID: selectedPostID)
        } else {
            store.deleteSelection(isSidebarFocused: NSApp.keyWindow?.firstResponder is NSTableView)
        }
    }

    private func forward(_ action: Selector) {
        NSApp.sendAction(action, to: nil, from: nil)
    }

    private func exportSelected(sendsViaAirDrop: Bool) {
        guard let id = store.selectedPostID else { return }
        exporter.export(id, in: store, sendsViaAirDrop: sendsViaAirDrop)
    }
}
