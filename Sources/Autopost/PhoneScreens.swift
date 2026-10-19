import AutopostCore
import SwiftUI

// The app keeps feed posts between 4:5 and 1.91:1 and crops anything outside that range.
private let tallestFeedRatio = 4.0 / 5.0
private let widestFeedRatio = 1.91
// Profile grid tiles have been 3:4 since 2025, so a 4:5 post loses a little off each side there.
private let gridTileRatio = 3.0 / 4.0

/// The selected post first, then the others, the way a follower scrolls into it.
struct FeedScreen: View {
    let handle: String

    @Environment(LibraryStore.self) private var store

    var body: some View {
        let posts = store.selectedPost.map { selected in [selected] + store.library.posts.filter { $0.id != selected.id } } ?? []

        VStack(spacing: 0) {
            HStack {
                Text("Home").font(.system(size: 24, weight: .bold))
                Spacer()
                Image(systemName: "heart")
                Image(systemName: "paperplane").padding(.leading, 18)
            }
            .font(.system(size: 22))
            .padding(.horizontal, 16)
            .frame(height: 44)

            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(posts.filter { !$0.photos.isEmpty }) { post in
                        FeedPost(post: post, handle: handle)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct FeedPost: View {
    let post: Post
    let handle: String

    @Environment(ThumbnailStore.self) private var thumbnails
    @State private var slide: Int? = 0

    var body: some View {
        let width = PhonePreviewView.screenSize.width
        // Every slide is cropped to the first one's shape.
        let firstRatio = FramedPhotoView.canvasRatio(thumbnails.thumbnail(for: post.photos[0].url), frame: post.frame)
        let ratio = min(max(firstRatio, tallestFeedRatio), widestFeedRatio)

        VStack(alignment: .leading, spacing: 0) {
            header
            carousel(width: width, ratio: ratio)
            actions
            VStack(alignment: .leading, spacing: 4) {
                Text("Liked by a friend and others").font(.system(size: 13, weight: .semibold))
                (Text(handle).bold() + Text("  \(post.name)"))
                    .font(.system(size: 13))
                Text("Just now").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Avatar(size: 32)
            Text(handle).font(.system(size: 13, weight: .semibold))
            Spacer()
            Image(systemName: "ellipsis")
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
    }

    private func carousel(width: Double, ratio: Double) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                // Identified by position, because the scroll position and the dots count slides.
                ForEach(post.photos.indices, id: \.self) { index in
                    FilledFramedPhoto(photo: post.photos[index], frame: post.frame, width: width, ratio: ratio)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $slide)
        .scrollIndicators(.hidden)
        .frame(width: width, height: width / ratio)
        .overlay(alignment: .topTrailing) {
            if post.photos.count > 1 {
                Text("\((slide ?? 0) + 1)/\(post.photos.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(12)
            }
        }
        .overlay { pagingArrows }
    }

    /// A mouse cannot swipe, so arrows page the carousel like the web version.
    private var pagingArrows: some View {
        HStack {
            if (slide ?? 0) > 0 {
                arrow("chevron.left") { slide = (slide ?? 0) - 1 }
            }
            Spacer()
            if (slide ?? 0) < post.photos.count - 1 {
                arrow("chevron.right") { slide = (slide ?? 0) + 1 }
            }
        }
        .padding(.horizontal, 10)
    }

    private func arrow(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.25)) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 26, height: 26)
                .background(.white.opacity(0.85), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var actions: some View {
        HStack(spacing: 16) {
            Image(systemName: "heart")
            Image(systemName: "bubble.right")
            Image(systemName: "paperplane")
            Spacer()
            Image(systemName: "bookmark")
        }
        .font(.system(size: 22))
        .padding(.horizontal, 14)
        .frame(height: 46)
        .overlay {
            if post.photos.count > 1 {
                HStack(spacing: 4) {
                    ForEach(0..<post.photos.count, id: \.self) { index in
                        Circle()
                            .fill(index == (slide ?? 0) ? Color.accentColor : Color.secondary.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
    }
}

/// The profile grid, newest post first, so the last post in the sidebar lands top left.
struct ProfileScreen: View {
    let handle: String

    @Environment(LibraryStore.self) private var store

    var body: some View {
        let posts = store.library.posts.reversed().filter { !$0.photos.isEmpty }

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(handle).font(.system(size: 22, weight: .bold))
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: "line.3.horizontal").font(.system(size: 22))
                }
                HStack(spacing: 28) {
                    Avatar(size: 86)
                    stat("\(posts.count)", "posts")
                    stat("1,204", "followers")
                    stat("388", "following")
                }
                Text("Photos on film and digital").font(.system(size: 13))
                HStack(spacing: 6) {
                    profileButton("Edit profile")
                    profileButton("Share profile")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            HStack {
                Image(systemName: "square.grid.3x3.fill").frame(maxWidth: .infinity)
                Image(systemName: "play.rectangle").frame(maxWidth: .infinity).foregroundStyle(.secondary)
                Image(systemName: "person.crop.square").frame(maxWidth: .infinity).foregroundStyle(.secondary)
            }
            .font(.system(size: 20))
            .frame(height: 40)

            grid(posts)
        }
        .scrollIndicators(.hidden)
    }

    private func grid(_ posts: [Post]) -> some View {
        let spacing = 2.0
        let tileWidth = (PhonePreviewView.screenSize.width - 2 * spacing) / 3
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(tileWidth), spacing: spacing), count: 3), spacing: spacing) {
            ForEach(posts) { post in
                FilledFramedPhoto(photo: post.photos[0], frame: post.frame, width: tileWidth, ratio: gridTileRatio)
                    .overlay(alignment: .topTrailing) {
                        if post.photos.count > 1 {
                            Image(systemName: "square.on.square.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                                .padding(6)
                        }
                    }
                    .overlay {
                        if post.id == store.selectedPostID {
                            Rectangle().strokeBorder(Color.accentColor, lineWidth: 2)
                        }
                    }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text(value).font(.system(size: 16, weight: .semibold))
            Text(label).font(.system(size: 13))
        }
    }

    private func profileButton(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// A framed photo cropped to fill a box of `ratio`, centred, the way the app crops feed slides and grid tiles.
struct FilledFramedPhoto: View {
    let photo: Photo
    let frame: FrameSettings
    let width: Double
    let ratio: Double

    @Environment(ThumbnailStore.self) private var thumbnails

    var body: some View {
        let photoRatio = FramedPhotoView.canvasRatio(thumbnails.thumbnail(for: photo.url), frame: frame)
        let height = width / ratio
        let size = photoRatio > ratio
            ? CGSize(width: height * photoRatio, height: height)
            : CGSize(width: width, height: width / photoRatio)

        FramedPhotoView(photo: photo, frame: frame)
            .frame(width: size.width, height: size.height)
            .frame(width: width, height: height)
            .clipped()
    }
}

private struct Avatar: View {
    let size: Double

    var body: some View {
        Circle()
            .fill(.quaternary)
            .overlay { Image(systemName: "person.fill").font(.system(size: size * 0.45)).foregroundStyle(.secondary) }
            .padding(size * 0.06)
            .overlay {
                Circle().strokeBorder(
                    AngularGradient(colors: [.orange, .pink, .purple, .orange], center: .center),
                    lineWidth: size * 0.05
                )
            }
            .frame(width: size, height: size)
    }
}
