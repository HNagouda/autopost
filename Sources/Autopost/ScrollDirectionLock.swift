import AppKit

/// Keeps each trackpad scroll in the direction it started, the way a phone does. A two-finger scroll down the feed
/// always drifts a little sideways, and without this the drift pages the carousel under the fingers to its next photo.
@MainActor
final class ScrollDirectionLock {
    private var monitor: Any?
    // Nil until the first movement of a gesture shows which way it goes.
    private var isVertical: Bool?

    func start() {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.locked(event) ?? event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    /// The event with its movement across the locked direction removed. Mouse wheels have no gesture phases and
    /// pass through untouched.
    private func locked(_ event: NSEvent) -> NSEvent {
        guard !event.phase.isEmpty || !event.momentumPhase.isEmpty else { return event }
        if event.phase == .began { isVertical = nil }

        let dx = abs(event.scrollingDeltaX)
        let dy = abs(event.scrollingDeltaY)
        if isVertical == nil, dx + dy > 0 { isVertical = dy >= dx }
        guard let isVertical, let copy = event.cgEvent?.copy() else { return event }

        // Axis 1 is vertical and axis 2 horizontal; each is stored three ways and all three must agree.
        let fields: [CGEventField] = isVertical
            ? [.scrollWheelEventDeltaAxis2, .scrollWheelEventPointDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2]
            : [.scrollWheelEventDeltaAxis1, .scrollWheelEventPointDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1]
        for field in fields {
            copy.setDoubleValueField(field, value: 0)
        }

        return NSEvent(cgEvent: copy) ?? event
    }
}
