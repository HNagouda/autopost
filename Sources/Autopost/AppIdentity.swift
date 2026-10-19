import Foundation

enum AppIdentity {
    // build-app.sh sets the bundle identifier from BUNDLE_ID, so a fork's Keychain items, pasteboard data and
    // preferences stay apart from other builds. The fallback covers `swift run`, which has no bundle.
    static let bundleID = Bundle.main.bundleIdentifier ?? "io.github.hnagouda.autopost"
}
