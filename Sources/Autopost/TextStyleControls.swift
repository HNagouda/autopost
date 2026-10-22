import AppKit
import AutopostCore
import SwiftUI

/// Font, size, bold, italic and letter spacing, shared by text boxes and the caption so both look and behave the same.
struct TextStyleControls<Trailing: View>: View {
    @Binding var fontFamily: String
    @Binding var size: Double
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var tracking: Double
    // Shown after bold and italic, such as the alignment picker for text boxes.
    @ViewBuilder var trailingStyle: () -> Trailing

    // Shown first; the rest of the installed families follow.
    static var favoriteFamilies: [String] {
        [
            TextBox.systemFontFamily, "Helvetica Neue", "Avenir Next", "Futura", "Gill Sans", "Didot",
            "Baskerville", "Georgia", "American Typewriter", "Courier New", "Snell Roundhand",
        ]
    }
    // Font size limits as a fraction of the canvas width.
    private static var sizeRange: ClosedRange<Double> { 0.008...0.2 }
    private static var trackingRange: ClosedRange<Double> { -0.05...0.5 }
    // Reference width for showing font size in pixels, the Instagram export width.
    private static var referenceWidth: Double { 1080 }

    // Read fresh each time rather than kept, so a font installed while the app is open shows up straight away.
    private static var otherFamilies: [String] {
        let favorites = Set(favoriteFamilies)
        return NSFontManager.shared.availableFontFamilies.filter { !favorites.contains($0) && !$0.hasPrefix(".") }
    }

    var body: some View {
        Picker("Font", selection: $fontFamily) {
            ForEach(Self.favoriteFamilies, id: \.self) { family in
                Text(family == TextBox.systemFontFamily ? "System (SF Pro)" : family).tag(family)
            }
            Divider()
            ForEach(Self.otherFamilies, id: \.self) { Text($0).tag($0) }
        }

        LabeledContent("Size") {
            Slider(value: $size, in: Self.sizeRange)
            SliderValueField(value: $size, range: Self.sizeRange, scale: Self.referenceWidth, unit: " px", width: 60)
        }

        LabeledContent("Style") {
            Toggle(isOn: $isBold) { Image(systemName: "bold") }
                .toggleStyle(.button).help("Bold")
            Toggle(isOn: $isItalic) { Image(systemName: "italic") }
                .toggleStyle(.button).help("Italic")
            trailingStyle()
        }

        LabeledContent("Spacing") {
            Slider(value: $tracking, in: Self.trackingRange)
        }
    }
}

extension TextStyleControls where Trailing == EmptyView {
    init(fontFamily: Binding<String>, size: Binding<Double>, isBold: Binding<Bool>, isItalic: Binding<Bool>, tracking: Binding<Double>) {
        self.init(fontFamily: fontFamily, size: size, isBold: isBold, isItalic: isItalic, tracking: tracking) { EmptyView() }
    }
}
