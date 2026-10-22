import AppKit
import SwiftUI

@main
struct AutopostApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var store = LibraryStore()
    @State private var thumbnails = ThumbnailStore()
    @State private var exporter = ExportController()
    @State private var editor = EditorSession()
    @State private var instagram = InstagramAccount()
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system

    var body: some Scene {
        Window("Autopost", id: WindowID.main) {
            ContentView()
                .environment(store)
                .environment(thumbnails)
                .environment(exporter)
                .environment(editor)
                .environment(instagram)
                .onAppear { theme.apply() }
                .onChange(of: theme) { theme.apply() }
        }
        .defaultSize(width: 1280, height: 820)
        .commands { AutopostCommands(store: store, exporter: exporter, editor: editor) }

        Window("Autopost Tour", id: WindowID.tour) {
            TourView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Window("Backups", id: WindowID.backups) {
            BackupsView()
                .environment(store)
        }
        .defaultSize(width: 520, height: 460)

        Settings {
            SettingsView()
                .environment(instagram)
        }
    }
}

enum WindowID {
    static let main = "main"
    static let backups = "backups"
    static let tour = "tour"

    /// SwiftUI gives a scene's window the scene's id as its identifier, so "main" finds the main window.
    @MainActor
    static func isMain(_ window: NSWindow?) -> Bool {
        window?.identifier?.rawValue == main
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
