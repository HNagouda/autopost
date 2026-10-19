import AutopostCore
import SwiftUI

enum PhoneScreen: String, CaseIterable {
    case feed
    case profile
}

/// Light and dark are what different followers see; the frame color reads very differently on each.
enum PhoneScheme: String, CaseIterable {
    case light
    case dark

    var colorScheme: ColorScheme { self == .light ? .light : .dark }

    // The app's dark mode is pure black, not the grey macOS uses.
    var screenBackground: Color { self == .light ? .white : .black }
}

/// A phone showing the selected post in a feed and on a profile grid, updated live as the frame changes.
struct PhonePreviewView: View {
    // iPhone 15 screen in points; the phone is drawn at this size and scaled to the window.
    static let screenSize = CGSize(width: 393, height: 852)
    static let bezel = 12.0
    static let cornerRadius = 55.0

    @Environment(LibraryStore.self) private var store
    @AppStorage("phoneScreen") private var screen = PhoneScreen.feed
    @AppStorage("phoneScheme") private var scheme = PhoneScheme.light
    @AppStorage("phoneHandle") private var handle = "your.handle"

    var body: some View {
        VStack(spacing: 16) {
            controls
            GeometryReader { geometry in
                let phone = CGSize(width: Self.screenSize.width + 2 * Self.bezel, height: Self.screenSize.height + 2 * Self.bezel)
                let scale = min(geometry.size.width / phone.width, geometry.size.height / phone.height, 1.2)
                phoneBody
                    .scaleEffect(scale)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .padding(20)
        .frame(minWidth: 320, minHeight: 600)
        .background(.background.secondary)
    }

    private var controls: some View {
        HStack {
            Picker("Screen", selection: $screen) {
                Label("Feed", systemImage: "house").tag(PhoneScreen.feed)
                Label("Profile", systemImage: "square.grid.3x3").tag(PhoneScreen.profile)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Picker("Phone appearance", selection: $scheme) {
                Image(systemName: "sun.max").tag(PhoneScheme.light)
                Image(systemName: "moon").tag(PhoneScheme.dark)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help("What followers in light or dark mode will see")

            TextField("Handle", text: $handle)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 140)
        }
    }

    private var phoneBody: some View {
        VStack(spacing: 0) {
            PhoneStatusBar()
            Group {
                switch screen {
                case .feed: FeedScreen(handle: handle)
                case .profile: ProfileScreen(handle: handle)
                }
            }
            .frame(maxHeight: .infinity)
            PhoneTabBar(screen: screen)
        }
        .frame(width: Self.screenSize.width, height: Self.screenSize.height)
        .background(scheme.screenBackground)
        .foregroundStyle(.primary)
        .environment(\.colorScheme, scheme.colorScheme)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius - Self.bezel, style: .continuous))
        .padding(Self.bezel)
        .background(.black, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(Color(white: 0.35), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
    }
}

private struct PhoneStatusBar: View {
    var body: some View {
        HStack {
            Text("9:41").font(.system(size: 16, weight: .semibold))
            Spacer()
            Capsule().fill(.black).frame(width: 120, height: 34)
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
            }
            .font(.system(size: 14, weight: .semibold))
        }
        .padding(.horizontal, 30)
        .padding(.top, 12)
        .frame(height: 54)
    }
}

private struct PhoneTabBar: View {
    let screen: PhoneScreen

    var body: some View {
        HStack {
            Image(systemName: screen == .feed ? "house.fill" : "house")
            Spacer()
            Image(systemName: "magnifyingglass")
            Spacer()
            Image(systemName: "plus.app")
            Spacer()
            Image(systemName: "play.rectangle")
            Spacer()
            Image(systemName: screen == .profile ? "person.crop.circle.fill" : "person.crop.circle")
        }
        .font(.system(size: 22))
        .padding(.horizontal, 28)
        .padding(.top, 10)
        .frame(height: 82, alignment: .top)
        .overlay(alignment: .top) { Divider() }
    }
}
