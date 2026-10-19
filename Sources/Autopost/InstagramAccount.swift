import AutopostCore
import Foundation
import Observation
import Security

/// The optional link to the user's real Instagram account, so the phone preview shows their profile and posts.
@MainActor @Observable
final class InstagramAccount {
    private(set) var profile: InstagramProfile?
    private(set) var media: [InstagramMedia] = []
    private(set) var isLoading = false
    private(set) var failureMessage: String?

    var isConnected: Bool { profile != nil }

    init() {
        Task { await reload() }
    }

    /// Checks the pasted token against Instagram and keeps it only if it works.
    func connect(token: String) async {
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.isEmpty {
            failureMessage = "Paste an access token first."
            return
        }

        if await load(token: token) {
            store(token)
            await refresh(token)
        }
    }

    func reload() async {
        let token: String?
        do {
            token = try TokenKeychain.read()
        } catch {
            NSLog("Autopost: could not read the Instagram token from the Keychain: %@", String(describing: error))
            failureMessage = "Autopost could not read the saved token from the Keychain."
            return
        }

        guard let token else { return }
        if await load(token: token) {
            await refresh(token)
        }
    }

    func disconnect() {
        do {
            try TokenKeychain.delete()
        } catch {
            NSLog("Autopost: could not delete the Instagram token from the Keychain: %@", String(describing: error))
            failureMessage = "Autopost could not remove the saved token from the Keychain."
            return
        }

        profile = nil
        media = []
        failureMessage = nil
    }

    /// Fetches profile and posts together. On failure the last good data stays, with the reason next to it.
    private func load(token: String) async -> Bool {
        isLoading = true
        failureMessage = nil
        defer { isLoading = false }

        do {
            async let loadedProfile = InstagramAPI.profile(token: token)
            async let loadedMedia = InstagramAPI.recentMedia(token: token)
            profile = try await loadedProfile
            media = try await loadedMedia
            return true
        } catch {
            NSLog("Autopost: could not load the Instagram account: %@", String(describing: error))
            failureMessage = error.localizedDescription
            return false
        }
    }

    // Each refresh restarts the 60-day clock, so a token keeps working as long as the app is opened now and then.
    // A failed refresh leaves the old token in place, which still works until it expires.
    private func refresh(_ token: String) async {
        do {
            let refreshed = try await InstagramAPI.refreshedToken(token: token)
            try TokenKeychain.save(refreshed.accessToken)
        } catch {
            NSLog("Autopost: could not refresh the Instagram token, keeping the old one: %@", String(describing: error))
        }
    }

    private func store(_ token: String) {
        do {
            try TokenKeychain.save(token)
        } catch {
            NSLog("Autopost: could not save the Instagram token to the Keychain: %@", String(describing: error))
            failureMessage = "Connected, but Autopost could not save the token, so you will need to paste it again next time."
        }
    }
}

/// The access token as a generic password in the login Keychain, never in UserDefaults or the library JSON.
private enum TokenKeychain {
    static let service = "nl.harsh.autopost.instagram"
    static let account = "access-token"

    struct Failure: Error {
        let status: OSStatus
    }

    static func read() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else { throw Failure(status: status) }

        return String(decoding: data, as: UTF8.self)
    }

    static func save(_ token: String) throws {
        let data = Data(token.utf8)
        let status = SecItemUpdate(baseQuery() as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess {
            return
        }
        guard status == errSecItemNotFound else { throw Failure(status: status) }

        var item = baseQuery()
        item[kSecValueData as String] = data
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw Failure(status: addStatus) }
    }

    static func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure(status: status) }
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
