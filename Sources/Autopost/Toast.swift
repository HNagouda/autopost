import SwiftUI

/// A short confirmation of something the user just did.
struct Toast: Identifiable {
    let id = UUID()
    var message: String
    var systemImage: String
    // The undo depth right after the change, when it can be undone. The Undo button only shows while that change
    // is still the latest, so it never undoes something newer instead.
    var undoDepth: Int?
}

/// Shows the store's latest toast at the bottom of the photo area and hides it again after a few seconds.
struct ToastView: View {
    // Long enough to read a sentence; a toast with Undo waits longer, so there is time to reach the button.
    private static let duration = Duration.seconds(2.5)
    private static let undoDuration = Duration.seconds(6)
    // Clear of the window edge, or of the floating selection bar under the grid while photos are selected.
    private static let bottomPadding = 16.0
    private static let aboveSelectionBarPadding = 64.0

    @Environment(LibraryStore.self) private var store
    @Environment(EditorSession.self) private var editor
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system

    var body: some View {
        let isSelectionBarShown = !editor.isOpen && !store.selectedPhotoIDs.isEmpty

        ZStack {
            if let toast = store.toast {
                content(toast)
                    .id(toast.id)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: toast.id) {
                        try? await Task.sleep(for: toast.undoDepth == nil ? Self.duration : Self.undoDuration)
                        guard !Task.isCancelled, store.toast?.id == toast.id else { return }
                        withAnimation { store.toast = nil }
                    }
            }
        }
        .animation(.spring(duration: 0.3), value: store.toast?.id)
        .padding(.bottom, isSelectionBarShown ? Self.aboveSelectionBarPadding : Self.bottomPadding)
    }

    /// Small and in the app's own colours, so it reads as part of the window rather than a grey pop-up.
    private func content(_ toast: Toast) -> some View {
        HStack(spacing: 8) {
            Image(systemName: toast.systemImage).foregroundStyle(.secondary)
            Text(toast.message).lineLimit(1)
            if let depth = toast.undoDepth, depth == store.undoDepth {
                Button("Undo") {
                    store.toast = nil
                    store.undo()
                }
                .buttonStyle(.borderless)
                .fontWeight(.semibold)
            }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.canvasBackground, in: Capsule())
        .overlay { Capsule().strokeBorder(.separator, lineWidth: 1) }
        .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
    }
}
