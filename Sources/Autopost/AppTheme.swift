import AppKit
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case amoled

    static let storageKey = "appTheme"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        case .amoled: "AMOLED Black"
        }
    }

    /// Set on NSApp rather than per view, so menus, sheets and every window follow along.
    func apply() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark, .amoled: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    /// The backdrop behind the photo grid. AMOLED goes pure black so white frames read like they will on an OLED phone.
    var canvasBackground: Color {
        switch self {
        case .amoled: .black
        case .system, .light, .dark: Color(nsColor: .underPageBackgroundColor)
        }
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            InstagramSettingsView()
                .tabItem { Label("Instagram", systemImage: "person.crop.square") }
        }
        .frame(width: 460)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system

    var body: some View {
        Form {
            Picker("Appearance", selection: $theme) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.inline)
        }
        .padding(24)
    }
}

extension View {
    /// Replaces the grey sidebar and inspector backgrounds with black in AMOLED mode.
    func amoledBackground(_ theme: AppTheme) -> some View {
        modifier(AmoledBackground(isActive: theme == .amoled))
    }
}

private struct AmoledBackground: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content.scrollContentBackground(.hidden).background(.black)
        } else {
            content
        }
    }
}
