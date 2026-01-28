//
//  Constants.swift
//  Trakt
//

import Foundation

enum TMDBConfig {
    static let baseURL = "https://api.themoviedb.org/3"
    static let imageBaseURL = "https://image.tmdb.org/t/p"
    static let apiKey = Secrets.tmdbAPIKey

    static func posterURL(path: String, size: String = "w154") -> URL? {
        URL(string: "\(imageBaseURL)/\(size)\(path)")
    }
}

enum TraktConfig {
    static let baseURL = "https://api.trakt.tv"
    static let apiVersion = "2"

    static let clientId = Secrets.traktClientId
    static let clientSecret = Secrets.traktClientSecret

    enum Endpoints {
        static let deviceCode = "/oauth/device/code"
        static let deviceToken = "/oauth/device/token"
        static let calendarShows = "/calendars/my/shows"
        static let watchedShows = "/sync/watched/shows"
        static let hiddenShows = "/users/hidden/progress_watched"
    }

    enum Keychain {
        static let accessToken = "trakt_access_token"
        static let refreshToken = "trakt_refresh_token"
        static let expiresAt = "trakt_expires_at"
    }
}
