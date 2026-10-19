import AppKit
import AutopostCore
import SwiftUI

/// Lists the library snapshots and puts one back. Restoring snapshots the current library first, so it can be undone here too.
struct BackupsView: View {
    @Environment(LibraryStore.self) private var store
    @State private var backups: [LibraryBackups.Backup] = []
    @State private var pending: LibraryBackups.Backup?
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Autopost saves a copy of your library at least every 10 minutes while you work, and before anything is deleted or restored. The newest \(LibraryBackups.keptBackups) are kept.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            List(backups) { backup in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(backup.date, format: .dateTime.weekday().day().month().hour().minute())
                        Text(backup.date, format: .relative(presentation: .named))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Restore…") { pending = backup }
                }
            }
            .overlay {
                if backups.isEmpty { ContentUnavailableView("No backups yet", systemImage: "clock.arrow.circlepath") }
            }

            HStack {
                Button("Show in Finder") { NSWorkspace.shared.open(store.backups.folder) }
                Spacer()
                Button("Refresh") { backups = store.backups.list() }
            }
        }
        .padding(20)
        .onAppear { backups = store.backups.list() }
        .confirmationDialog("Replace your library with this backup?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button("Restore") { restore() }
        } message: {
            Text("Your current library is backed up first, so you can come back to it from this list.")
        }
        .alert("Could not restore", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK") {}
        } message: {
            Text(failure ?? "")
        }
    }

    private func restore() {
        guard let backup = pending else { return }
        do {
            try store.restoreBackup(backup)
            backups = store.backups.list()
        } catch {
            failure = "That backup could not be read: \(error.localizedDescription)"
            NSLog("Autopost: restoring %@ failed: %@", backup.url.path, String(describing: error))
        }
    }
}
