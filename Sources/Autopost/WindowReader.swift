import AppKit
import SwiftUI

/// Reports the window a view lives in, so a key monitor can ignore key presses meant for other windows.
struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> ReportingView {
        ReportingView(onWindow: onWindow)
    }

    func updateNSView(_ view: ReportingView, context: Context) {}

    final class ReportingView: NSView {
        let onWindow: (NSWindow?) -> Void

        init(onWindow: @escaping (NSWindow?) -> Void) {
            self.onWindow = onWindow
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("ReportingView is only made in code.")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindow(window)
        }
    }
}
