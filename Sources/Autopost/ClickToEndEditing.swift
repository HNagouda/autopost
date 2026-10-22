import AppKit

/// Ends typing in a text field when the user clicks anywhere outside it. AppKit only moves the cursor out when the
/// click lands on another control, so clicking the photos or empty space would otherwise leave the field active.
@MainActor
final class ClickToEndEditing {
    private var monitor: Any?

    func start() {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            Self.endEditingIfOutside(event)
            return event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    /// While a field is being typed in, the cursor lives in a shared field editor whose delegate is that field.
    private static func endEditingIfOutside(_ event: NSEvent) {
        guard let window = event.window,
              let editor = window.firstResponder as? NSTextView,
              let field = editor.delegate as? NSView,
              let frameView = window.contentView?.superview
        else { return }

        // The frame view's coordinates are the window's, so the click location can be hit-tested as it is.
        let clicked = frameView.hitTest(event.locationInWindow)
        if let clicked, clicked.isDescendant(of: field) { return }
        window.makeFirstResponder(nil)
    }
}
