import AppKit
import AutopostCore
import SwiftUI

struct ContentView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(ExportController.self) private var exporter
    @Environment(EditorSession.self) private var editor
    @Environment(\.openWindow) private var openWindow
    @AppStorage(TileSize.storageKey) private var tileWidth = TileSize.standard
    @AppStorage(TourView.seenKey) private var seenTourEdition = 0
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system
    @AppStorage(PhonePreviewView.shownKey) private var isPhoneShown = false
    @State private var isInspectorShown = true
    @State private var columns = NavigationSplitViewVisibility.all
    @State private var panelKeyMonitor: Any?
    @State private var clickToEndEditing = ClickToEndEditing()

    var body: some View {
        @Bindable var exporter = exporter

        NavigationSplitView(columnVisibility: $columns) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 250)
                // The system puts the sidebar button next to the window buttons; this one sits at the sidebar's right edge.
                .toolbar(removing: .sidebarToggle)
                .toolbar { sidebarToolbar }
        } detail: {
            HStack(spacing: 0) {
                workArea
                // Next to the photos and the settings, so a border or text change shows on the phone as it happens.
                if isPhoneShown {
                    Divider()
                    PhonePreviewView()
                        .frame(width: PhonePreviewView.panelWidth)
                        .transition(.move(edge: .trailing))
                }
            }
        }
        .inspector(isPresented: $isInspectorShown) {
            Group {
                if let post = store.selectedPost, let photoID = editor.photoID {
                    PhotoInspector(postID: post.id, photoID: photoID)
                } else if let post = store.selectedPost {
                    InspectorView(postID: post.id)
                } else {
                    Text("No post selected").foregroundStyle(.secondary)
                }
            }
            .inspectorColumnWidth(min: 300, ideal: 320, max: 380)
            // Above the inspector, next to the settings they belong with, so the space over the photos stays empty.
            .toolbar {
                FlexibleToolbarSpace()
                actionItems
            }
        }
        .toolbar {
            navigationItems
            // With the inspector hidden its buttons go with it, so they move over the photos instead.
            if !isInspectorShown { actionItems }
        }
        // The toolbar takes the photo area's colour, so no grey band sits above the photos.
        .toolbarBackground(theme.canvasBackground, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .onChange(of: store.selectedPostID) { editor.close() }
        .onAppear {
            startPanelKeyMonitor()
            clickToEndEditing.start()
            if seenTourEdition < TourView.edition { openWindow(id: WindowID.tour) }
        }
        .onDisappear {
            stopPanelKeyMonitor()
            clickToEndEditing.stop()
        }
        .alert("Export failed", isPresented: Binding(get: { exporter.failure != nil }, set: { if !$0 { exporter.failure = nil } })) {
            Button("OK") { exporter.failure = nil }
        } message: {
            Text(exporter.failure ?? "")
        }
    }

    /// The post's photos or the open photo, with its toasts centred under it.
    private var workArea: some View {
        Group {
            if let post = store.selectedPost, editor.isOpen {
                PhotoEditorView(postID: post.id)
                    .navigationTitle(post.name)
                    .navigationSubtitle(editorSubtitle(for: post))
            } else if let post = store.selectedPost {
                PostGridView(postID: post.id)
                    .navigationTitle(post.name)
                    .navigationSubtitle(subtitle(for: post))
            } else {
                EmptyLibraryView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Centred under the photos, not under the whole window.
        .overlay(alignment: .bottom) { ToastView() }
    }

    private func subtitle(for post: Post) -> String {
        "\(LibraryStore.photoCount(post.photos.count)) · \(post.frame.ratioLabel)"
    }

    private func editorSubtitle(for post: Post) -> String {
        let index = post.photos.firstIndex { $0.id == editor.photoID }.map { $0 + 1 } ?? 0
        return "Photo \(index) of \(post.photos.count) · \(post.frame.ratioLabel)"
    }

    @ToolbarContentBuilder
    private var sidebarToolbar: some ToolbarContent {
        FlexibleToolbarSpace()
        ToolbarItem { sidebarButton }
    }

    private var sidebarButton: some View {
        Button("Toggle Sidebar", systemImage: "sidebar.left") { toggleSidebar() }
            .help(columns == .detailOnly ? "Show the posts (P)" : "Hide the posts (P)")
    }

    @ToolbarContentBuilder
    private var navigationItems: some ToolbarContent {
        // With the sidebar hidden its own button goes with it, so the button to bring it back sits here.
        if columns == .detailOnly {
            ToolbarItem(placement: .navigation) { sidebarButton }
        }
        if editor.isOpen {
            ToolbarItem(placement: .navigation) {
                Button("Back to Post", systemImage: "chevron.left") { editor.close() }
                    .help("Back to the post (Esc)")
            }
        }
    }

    @ToolbarContentBuilder
    private var actionItems: some ToolbarContent {
        if editor.isOpen {
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: Binding(
                    get: { editor.isCropping },
                    set: { isCropping in
                        guard let postID = store.selectedPostID else { return }
                        if isCropping, let photoID = editor.photoID {
                            editor.crop(photoID, in: store, postID: postID)
                        } else {
                            editor.applyCrop(in: store, postID: postID)
                        }
                    }
                )) {
                    Label("Crop", systemImage: "crop")
                }
                .help("Crop this photo (C)")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add Text", systemImage: "textformat") {
                    if let id = store.selectedPostID { editor.addTextBox(in: store, postID: id) }
                }
                .help("Add a text box (⌘T)")
            }
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: Binding(get: { editor.isShowingGrid }, set: { editor.isShowingGrid = $0 })) {
                    Label("Grid", systemImage: "grid")
                }
                .help("Show the snapping grid. Hold Shift while dragging to place text freely.")
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                Slider(value: $tileWidth, in: TileSize.range) {
                    Text("Photo size")
                } minimumValueLabel: {
                    Image(systemName: "minus").imageScale(.small)
                } maximumValueLabel: {
                    Image(systemName: "plus").imageScale(.small)
                }
                // Wide enough to drag comfortably, narrow enough that the four buttons still fit above the inspector
                // at its smallest width.
                .frame(width: 130)
                .help("Photo size (⇧- and ⇧+)")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Add Photos", systemImage: "photo.badge.plus") { store.addPhotosToSelectedPost(FileImport.choosePhotos(allowsFolders: false)) }
                .help("Add photos to this post (⌘O)")
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Phone Preview", systemImage: "iphone") { togglePhonePreview() }
                .help("Show or hide the phone preview (⇧P)")
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Export", systemImage: "square.and.arrow.up") {
                if let id = store.selectedPostID { exporter.export(id, in: store) }
            }
            .disabled(store.selectedPost?.photos.isEmpty ?? true)
            .help("Export this post (⌘E)")
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Inspector", systemImage: "sidebar.right") { isInspectorShown.toggle() }
        }
    }

    // * ====================================================================
    // * === panel keys
    // * ====================================================================

    /// P shows and hides the posts column and ⇧P the phone preview. Plain keys need a monitor: as menu shortcuts
    /// they would also fire while typing a P in a text field.
    private func startPanelKeyMonitor() {
        panelKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard WindowID.isMain(event.window), !KeyCode.isTyping(in: event.window) else { return event }

            if modifiers == .shift && event.charactersIgnoringModifiers == "P" {
                togglePhonePreview()
                return nil
            }
            if modifiers.isEmpty && event.charactersIgnoringModifiers == "p" {
                toggleSidebar()
                return nil
            }
            return event
        }
    }

    private func stopPanelKeyMonitor() {
        if let panelKeyMonitor { NSEvent.removeMonitor(panelKeyMonitor) }
        panelKeyMonitor = nil
    }

    private func toggleSidebar() {
        withAnimation { columns = columns == .detailOnly ? .all : .detailOnly }
    }

    private func togglePhonePreview() {
        withAnimation(PhonePreviewView.panelAnimation) { isPhoneShown.toggle() }
    }
}

struct EmptyLibraryView: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        ContentUnavailableView {
            Label("No posts yet", systemImage: "rectangle.portrait.on.rectangle.portrait")
        } description: {
            Text("Drop photos or folders here. Each folder becomes its own post.")
        } actions: {
            Button("New Post") { store.createPost(startsRenaming: true) }
            Button("Create Posts from Folders…") { store.createPosts(from: FileImport.choosePhotos(allowsFolders: true)) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dropDestination(for: URL.self) { urls, _ in
            store.createPosts(from: urls)
            return true
        }
    }
}

/// Pushes the toolbar items after it to the right edge of their column. Toolbar spacers arrived in macOS 26; on
/// macOS 14 and 15 this is empty and the items sit at the left, which is only a difference in looks.
struct FlexibleToolbarSpace: ToolbarContent {
    var body: some ToolbarContent {
        if #available(macOS 26, *) {
            ToolbarSpacer(.flexible)
        }
    }
}
