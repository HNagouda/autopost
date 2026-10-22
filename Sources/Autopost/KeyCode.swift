import AppKit

/// Hardware key codes for keys whose job does not depend on the keyboard layout. Letters and symbols (C, /, -, +)
/// are matched by the character they type instead, so C crops on any layout.
enum KeyCode {
    static let delete: UInt16 = 51
    static let forwardDelete: UInt16 = 117
    static let escape: UInt16 = 53
    static let returnKey: UInt16 = 36
    static let keypadEnter: UInt16 = 76
    static let left: UInt16 = 123
    static let right: UInt16 = 124
    static let down: UInt16 = 125
    static let up: UInt16 = 126

    // The number row and the keypad. Matched by position, because on an AZERTY keyboard the number row types
    // & é " and so on unless Shift is held.
    private static let digits: [UInt16: Int] = [
        29: 0, 18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9,
        82: 0, 83: 1, 84: 2, 85: 3, 86: 4, 87: 5, 88: 6, 89: 7, 91: 8, 92: 9,
    ]

    static func digit(_ keyCode: UInt16) -> Int? {
        digits[keyCode]
    }

    static func isDelete(_ keyCode: UInt16) -> Bool {
        keyCode == delete || keyCode == forwardDelete
    }

    static func isArrow(_ keyCode: UInt16) -> Bool {
        [left, right, up, down].contains(keyCode)
    }

    /// True while the cursor is in a text field, where every key belongs to the typing.
    static func isTyping(in window: NSWindow?) -> Bool {
        window?.firstResponder is NSText
    }

    /// True for a plain key press, or one with only Shift held.
    static func hasNoShortcutModifiers(_ event: NSEvent) -> Bool {
        event.modifierFlags.intersection([.command, .option, .control]).isEmpty
    }
}

/// The carousel position typed on the number keys. Two digits typed quickly read as one number, so 1 then 2 is 12.
struct TypedPosition {
    // Long enough to type a second digit, short enough that pressing 2 a moment later means 2 again.
    private static let joinWindow: TimeInterval = 0.8

    private var value = 0
    private var lastTyped = Date.distantPast

    /// The position to move to after typing `digit`, or nil when it names no photo.
    mutating func type(_ digit: Int, photoCount: Int) -> Int? {
        let now = Date()
        let joined = value * 10 + digit
        let isJoining = now.timeIntervalSince(lastTyped) < Self.joinWindow && joined <= photoCount
        value = isJoining ? joined : digit
        lastTyped = now
        return (1...max(photoCount, 1)).contains(value) ? value : nil
    }
}
