import AppKit
import SwiftUI

@main
struct AutopostApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var store = LibraryStore()
    @State private var thumbnails = ThumbnailStore()
    @State private var exporter = ExportController()
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system

    var body: some Scene {
        Window("Autopost", id: WindowID.main) {
            ContentView()
                .environment(store)
                .environment(thumbnails)
                .environment(exporter)
                .onAppear { theme.apply() }
                .onChange(of: theme) { theme.apply() }
        }
        .defaultSize(width: 1280, height: 820)
        .commands { AutopostCommands(store: store, exporter: exporter) }

        Window("Phone Preview", id: WindowID.phone) {
            PhonePreviewView()
                .environment(store)
                .environment(thumbnails)
        }
        .defaultSize(width: 460, height: 900)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
        }
    }
}

enum WindowID {
    static let main = "main"
    static let phone = "phone"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
