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

/// A phone showing the selected post in a feed and on a profile grid, in a panel beside the photos, updated live
/// as the frame changes.
struct PhonePreviewView: View {
    static let shownKey = "isPhonePreviewShown"
    // Wide enough for the controls on one row and a phone that is still readable.
    static let panelWidth = 320.0
    // Used by ⇧P and the menu command alike, so the panel slides the same way from both.
    static let panelAnimation = Animation.easeOut(duration: 0.25)

    // iPhone 15 screen in points; the phone is drawn at this size and scaled to the window.
    static let screenSize = CGSize(width: 393, height: 852)
    static let bezel = 12.0
    static let cornerRadius = 55.0
    // The panel can be laid out at zero size for a moment at launch. A zero scale cannot be inverted and makes
    // AppKit stop the app, so the phone never shrinks below this.
    private static let minimumScale = 0.05

    @Environment(LibraryStore.self) private var store
    @Environment(InstagramAccount.self) private var instagram
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system
    @AppStorage("phoneScreen") private var screen = PhoneScreen.feed
    @AppStorage("phoneScheme") private var scheme = PhoneScheme.light
    @AppStorage("phoneHandle") private var handle = "your.handle"

    var body: some View {
        VStack(spacing: 16) {
            controls
            GeometryReader { geometry in
                let phone = CGSize(width: Self.screenSize.width + 2 * Self.bezel, height: Self.screenSize.height + 2 * Self.bezel)
                let scale = max(min(geometry.size.width / phone.width, geometry.size.height / phone.height, 1.2), Self.minimumScale)
                phoneBody
                    .scaleEffect(scale)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .padding(16)
        .background(theme.canvasBackground)
    }

    private var controls: some View {
        HStack(spacing: 8) {
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

            // A connected account shows its real username, so there is nothing to type.
            if !instagram.isConnected {
                HandleField(handle: $handle)
            }
        }
    }

    private var phoneBody: some View {
        let shownHandle = instagram.profile?.username ?? handle

        return VStack(spacing: 0) {
            PhoneStatusBar()
            Group {
                switch screen {
                case .feed: FeedScreen(handle: shownHandle)
                case .profile: ProfileScreen(handle: shownHandle)
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

/// The handle as plain text until clicked. A text field here would take the cursor as soon as the window opens,
/// and then ⇧P would type a P instead of closing the preview.
private struct HandleField: View {
    @Binding var handle: String

    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        if isEditing {
            TextField("Handle", text: $handle)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 140)
                .focused($isFocused)
                .onSubmit { isEditing = false }
                .onExitCommand { isEditing = false }
                .onChange(of: isFocused) {
                    if !isFocused { isEditing = false }
                }
                .onAppear { Task { @MainActor in isFocused = true } }
        } else {
            Button("@\(handle)") { isEditing = true }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Click to change the handle shown on the phone")
        }
    }
}
