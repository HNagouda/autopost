import SwiftUI

/// A few pages showing what Autopost can do and the keys for it. Opens once on first launch, and again from
/// Help > Autopost Tour, because most of these features are a key press nobody would guess.
struct TourView: View {
    // Raise this when the tour gains pages worth showing again to people who have already seen it.
    static let edition = 1
    static let seenKey = "seenTourEdition"

    @AppStorage(seenKey) private var seenEdition = 0
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var pageIndex = 0

    var body: some View {
        let page = TourPage.all[pageIndex]
        let isLast = pageIndex == TourPage.all.count - 1

        VStack(spacing: 18) {
            Image(systemName: page.symbol)
                .font(.system(size: 42))
                .foregroundStyle(.tint)
                .frame(height: 54)
            Text(page.title)
                .font(.title2.bold())
            Text(page.text)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(page.keys, id: \.key) { hint in
                    KeyHintRow(key: hint.key, meaning: hint.meaning)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            Spacer(minLength: 0)
            dots
            HStack {
                if !isLast {
                    Button("Skip Tour") { close() }
                        .buttonStyle(.borderless)
                }
                Spacer()
                if pageIndex > 0 {
                    Button("Back") { pageIndex -= 1 }
                }
                Button(isLast ? "Start Using Autopost" : "Next") {
                    if isLast { close() } else { pageIndex += 1 }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 480, height: 470)
        .animation(.easeOut(duration: 0.2), value: pageIndex)
        .onAppear { seenEdition = Self.edition }
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(TourPage.all.indices, id: \.self) { index in
                Circle()
                    .fill(index == pageIndex ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: 7, height: 7)
                    .onTapGesture { pageIndex = index }
            }
        }
    }

    private func close() {
        dismissWindow(id: WindowID.tour)
    }
}

private struct KeyHintRow: View {
    let key: String
    let meaning: String

    var body: some View {
        HStack(spacing: 12) {
            Text(key)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .frame(minWidth: 74)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            Text(meaning)
                .font(.callout)
        }
    }
}

private struct TourPage {
    struct KeyHint {
        var key: String
        var meaning: String
    }

    var symbol: String
    var title: String
    var text: String
    var keys: [KeyHint] = []

    // Every page of the tour, in order, in one place.
    static let all: [TourPage] = [
        TourPage(
            symbol: "rectangle.portrait.on.rectangle.portrait",
            title: "Welcome to Autopost",
            text: "Group your photos into posts, give each post a shape and a border, and export the whole carousel at once. This tour shows the shortcuts that make it quick."
        ),
        TourPage(
            symbol: "square.and.pencil",
            title: "Posts",
            text: "A new post starts with its name ready to type over. Deleted posts wait in Recently Deleted for 30 days, folded away at the bottom of the sidebar.",
            keys: [
                KeyHint(key: "⌘N", meaning: "New post, named straight away"),
                KeyHint(key: "⌘O", meaning: "Add photos to the post"),
                KeyHint(key: "Delete", meaning: "Delete the selected photos, or the post"),
                KeyHint(key: "P", meaning: "Hide or show the list of posts"),
            ]
        ),
        TourPage(
            symbol: "square.grid.3x3",
            title: "Arranging a carousel",
            text: "Click a photo, then press a number to move it to that spot. Drag photos onto a post in the sidebar to move them there.",
            keys: [
                KeyHint(key: "⌘Z", meaning: "Undo a move, delete, crop or any other change"),
                KeyHint(key: "←  →", meaning: "Step from photo to photo"),
                KeyHint(key: "1 – 9", meaning: "Move the selected photo there; type 1 2 for 12"),
                KeyHint(key: "⇧-click", meaning: "Select a run of photos, ⌘-click to pick single ones"),
            ]
        ),
        TourPage(
            symbol: "crop",
            title: "Cropping",
            text: "Drag the corners or edges, or drag inside to move the crop. The crop shapes the photo; the post's ratio still shapes the canvas and border around it.",
            keys: [
                KeyHint(key: "C", meaning: "Crop the selected or open photo"),
                KeyHint(key: "Shift", meaning: "Hold while dragging to keep the shape"),
                KeyHint(key: "Return", meaning: "Apply the crop, Esc to cancel"),
            ]
        ),
        TourPage(
            symbol: "camera",
            title: "Camera settings text",
            text: "Set a post's caption to Camera settings to print what each photo was shot with. Rename your camera once in the post's settings, so ILCE-6400 reads Sony a6400 everywhere. Open a photo to type its own settings, which is how film scans get theirs."
        ),
        TourPage(
            symbol: "iphone",
            title: "Editing and previewing",
            text: "Double-click a photo to edit it on its own, with the rest of the post in a filmstrip underneath.",
            keys: [
                KeyHint(key: "/", meaning: "Hide or show the filmstrip"),
                KeyHint(key: "⇧P", meaning: "Show or hide the phone beside your photos"),
                KeyHint(key: "⌘T", meaning: "Add text to the open photo"),
                KeyHint(key: "⇧−  ⇧+", meaning: "Smaller or larger photos in the grid"),
            ]
        ),
    ]
}
