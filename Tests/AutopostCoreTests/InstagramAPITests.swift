import Foundation
import Testing

@testable import AutopostCore

@Test func profilePayloadDecodesWithCounts() throws {
    let json = """
        {
          "user_id": "17841400000000000",
          "username": "harsh.shoots",
          "name": "Harsh",
          "profile_picture_url": "https://scontent.cdninstagram.com/avatar.jpg",
          "followers_count": 1204,
          "follows_count": 388,
          "media_count": 57,
          "id": "9000000000000000"
        }
        """
    let profile = try InstagramAPI.decode(InstagramProfile.self, from: Data(json.utf8))

    #expect(profile.username == "harsh.shoots")
    #expect(profile.profilePictureURL == URL(string: "https://scontent.cdninstagram.com/avatar.jpg"))
    #expect(profile.followersCount == 1204)
    #expect(profile.followsCount == 388)
    #expect(profile.mediaCount == 57)
}

@Test func profileWithoutPictureOrNameStillDecodes() throws {
    let json = """
        {"user_id": "1", "username": "a", "followers_count": 0, "follows_count": 0, "media_count": 0}
        """
    let profile = try InstagramAPI.decode(InstagramProfile.self, from: Data(json.utf8))

    #expect(profile.name == nil)
    #expect(profile.profilePictureURL == nil)
}

@Test func mediaPageTilesUseThumbnailForVideoAndMediaURLOtherwise() throws {
    let json = """
        {
          "data": [
            {"id": "1", "media_type": "IMAGE", "media_url": "https://cdn.example/1.jpg",
             "permalink": "https://www.instagram.com/p/AAA/", "timestamp": "2025-03-14T09:30:00+0000"},
            {"id": "2", "media_type": "VIDEO", "media_url": "https://cdn.example/2.mp4",
             "thumbnail_url": "https://cdn.example/2.jpg", "permalink": "https://www.instagram.com/reel/BBB/",
             "timestamp": "2025-03-10T18:00:00+0000"},
            {"id": "3", "media_type": "CAROUSEL_ALBUM", "media_url": "https://cdn.example/3-first.jpg",
             "permalink": "https://www.instagram.com/p/CCC/", "timestamp": "2025-03-01T12:00:00+0000"}
          ],
          "paging": {"cursors": {"before": "x", "after": "y"}}
        }
        """
    let media = try InstagramAPI.decode(InstagramMediaPage.self, from: Data(json.utf8)).data

    #expect(media.map(\.id) == ["1", "2", "3"])
    #expect(media[0].tileImageURL == URL(string: "https://cdn.example/1.jpg"))
    #expect(media[1].isVideo)
    #expect(media[1].tileImageURL == URL(string: "https://cdn.example/2.jpg"))
    #expect(media[2].isCarousel)
    #expect(media[2].tileImageURL == URL(string: "https://cdn.example/3-first.jpg"))
}

@Test func refreshedTokenPayloadDecodes() throws {
    let json = """
        {"access_token": "c3oxd", "token_type": "bearer", "expires_in": 5183944}
        """
    let token = try InstagramAPI.decode(InstagramToken.self, from: Data(json.utf8))

    #expect(token == InstagramToken(accessToken: "c3oxd", tokenType: "bearer", expiresIn: 5_183_944))
}

@Test func errorPayloadThrowsInstagramsMessage() {
    let json = """
        {"error": {"message": "Error validating access token: Session has expired.", "type": "OAuthException", "code": 190}}
        """

    #expect(throws: InstagramAPIError(message: "Error validating access token: Session has expired.")) {
        try InstagramAPI.decode(InstagramProfile.self, from: Data(json.utf8))
    }
}

@Test func unreadableResponseThrowsAPlainMessage() {
    #expect(throws: InstagramAPIError(message: "Instagram sent a response Autopost could not read.")) {
        try InstagramAPI.decode(InstagramProfile.self, from: Data("<html>".utf8))
    }
}
