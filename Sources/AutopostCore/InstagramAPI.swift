import Foundation

/// The account behind a token, as `GET /me` returns it.
public struct InstagramProfile: Codable, Equatable, Sendable {
    public var userID: String
    public var username: String
    public var name: String?
    // Missing when the account has no profile picture.
    public var profilePictureURL: URL?
    public var followersCount: Int
    public var followsCount: Int
    public var mediaCount: Int

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case username
        case name
        case profilePictureURL = "profile_picture_url"
        case followersCount = "followers_count"
        case followsCount = "follows_count"
        case mediaCount = "media_count"
    }
}

/// One published post, as `GET /me/media` lists it.
public struct InstagramMedia: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    // 'IMAGE', 'VIDEO' or 'CAROUSEL_ALBUM'. Kept as a string so a new type does not break the whole page.
    public var mediaType: String
    public var mediaURL: URL?
    public var thumbnailURL: URL?
    public var permalink: URL?
    // Like "2025-03-14T09:30:00+0000".
    public var timestamp: String?

    enum CodingKeys: String, CodingKey {
        case id
        case mediaType = "media_type"
        case mediaURL = "media_url"
        case thumbnailURL = "thumbnail_url"
        case permalink
        case timestamp
    }

    public var isVideo: Bool { mediaType == "VIDEO" }
    public var isCarousel: Bool { mediaType == "CAROUSEL_ALBUM" }

    /// The still a grid tile shows. A video's `media_url` is the video file, so it uses the thumbnail;
    /// a carousel's `media_url` is already its first slide.
    public var tileImageURL: URL? {
        isVideo ? thumbnailURL : mediaURL
    }
}

public struct InstagramMediaPage: Codable, Equatable, Sendable {
    public var data: [InstagramMedia]
}

/// A refreshed long-lived token, valid for another 60 days.
public struct InstagramToken: Codable, Equatable, Sendable {
    public var accessToken: String
    public var tokenType: String
    public var expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

/// What went wrong, in words the user can act on. Instagram's own message when it sent one.
public struct InstagramAPIError: LocalizedError, Equatable {
    public var message: String

    public var errorDescription: String? { message }
}

/// The few calls the phone preview needs from the Instagram API with Instagram Login.
public enum InstagramAPI {
    static let host = URL(string: "https://graph.instagram.com")!
    static let profileFields = "user_id,username,name,profile_picture_url,followers_count,follows_count,media_count"
    static let mediaFields = "id,media_type,media_url,thumbnail_url,permalink,timestamp"
    // Ten rows of the profile grid, which is more than the phone preview scrolls through in practice.
    static let mediaLimit = 30

    public static func profile(token: String) async throws -> InstagramProfile {
        let data = try await get("me", query: ["fields": profileFields], token: token)
        return try decode(InstagramProfile.self, from: data)
    }

    public static func recentMedia(token: String) async throws -> [InstagramMedia] {
        let query = ["fields": mediaFields, "limit": String(mediaLimit)]
        let data = try await get("me/media", query: query, token: token)
        return try decode(InstagramMediaPage.self, from: data).data
    }

    // Instagram only refreshes tokens that are at least 24 hours old, so a token pasted today fails here.
    public static func refreshedToken(token: String) async throws -> InstagramToken {
        let data = try await get("refresh_access_token", query: ["grant_type": "ig_refresh_token"], token: token)
        return try decode(InstagramToken.self, from: data)
    }

    /// Decodes `type`, or throws Instagram's `{"error": {"message": ...}}` when the body is an error.
    public static func decode<Response: Decodable>(_ type: Response.Type, from data: Data) throws -> Response {
        if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
            throw InstagramAPIError(message: envelope.error.message)
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            NSLog("Autopost: could not decode Instagram %@: %@", String(describing: type), String(describing: error))
            throw InstagramAPIError(message: "Instagram sent a response Autopost could not read.")
        }
    }

    private static func get(_ path: String, query: [String: String], token: String) async throws -> Data {
        var components = URLComponents(url: host.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            + [URLQueryItem(name: "access_token", value: token)]

        // Not logged with the URL, because the URL carries the token.
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return data
    }

    private struct ErrorEnvelope: Decodable {
        struct Body: Decodable {
            var message: String
        }

        var error: Body
    }
}
