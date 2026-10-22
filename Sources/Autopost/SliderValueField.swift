import SwiftUI

/// The number beside a slider, which can also be clicked and typed into, because typing 5.5 is quicker than
/// dragging to it. Return or clicking away applies the number, clamped to the slider's range; anything that is
/// not a number puts the old value back.
struct SliderValueField: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    // How the stored value is shown: quality is stored as 0.92 and shown as 92, so its scale is 100.
    var scale = 1.0
    var fractionDigits = 0
    var unit = ""
    var width = 44.0

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 1) {
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                // Return leaves the field, and leaving it applies the number.
                .onSubmit { isFocused = false }
                .onChange(of: isFocused) {
                    if !isFocused { commit() }
                }
            if !unit.isEmpty {
                Text(unit).foregroundStyle(.secondary)
            }
        }
        .monospacedDigit()
        .padding(.horizontal, 3)
        .background(.quaternary.opacity(isFocused ? 1 : 0.5), in: RoundedRectangle(cornerRadius: 4))
        .frame(width: width, alignment: .trailing)
        .help("Click to type a value")
        .onAppear { text = formatted }
        // Keeps the number in step while the slider is dragged, but never under the cursor while typing.
        .onChange(of: value) {
            if !isFocused { text = formatted }
        }
    }

    private var formatted: String {
        (value * scale).formatted(.number.precision(.fractionLength(fractionDigits)))
    }

    /// Accepts a comma as the decimal mark too, since that is how much of Europe types 5,5.
    private func commit() {
        // Clicking in and out without typing must not round the stored value to what the field shows.
        guard text != formatted else { return }
        let cleaned = text.replacingOccurrences(of: ",", with: ".").filter { $0.isNumber || $0 == "." || $0 == "-" }
        if let typed = Double(cleaned) {
            value = min(max(typed / scale, range.lowerBound), range.upperBound)
        }
        text = formatted
    }
}
