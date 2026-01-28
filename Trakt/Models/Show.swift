//
//  Show.swift
//  Trakt
//

import Foundation

struct Show: Codable, Identifiable {
    let title: String
    let year: Int?
    let ids: ShowIds

    var id: Int { ids.trakt }
}

struct ShowIds: Codable {
    let trakt: Int
    let slug: String?
    let tvdb: Int?
    let imdb: String?
    let tmdb: Int?
}

// MARK: - Watched Progress Models

struct WatchedShow: Codable {
    let plays: Int
    let lastWatchedAt: Date?
    let lastUpdatedAt: Date?
    let show: Show
    let seasons: [WatchedSeason]

    enum CodingKeys: String, CodingKey {
        case plays
        case lastWatchedAt = "last_watched_at"
        case lastUpdatedAt = "last_updated_at"
        case show
        case seasons
    }
}

struct WatchedSeason: Codable {
    let number: Int
    let episodes: [WatchedEpisode]
}

struct WatchedEpisode: Codable {
    let number: Int
    let plays: Int
    let lastWatchedAt: Date?

    enum CodingKeys: String, CodingKey {
        case number
        case plays
        case lastWatchedAt = "last_watched_at"
    }
}

// MARK: - Show Progress (for Up Next)

struct ShowProgress: Codable {
    let aired: Int
    let completed: Int
    let lastWatchedAt: Date?
    let nextEpisode: ProgressEpisode?
    let lastEpisode: ProgressEpisode?

    enum CodingKeys: String, CodingKey {
        case aired
        case completed
        case lastWatchedAt = "last_watched_at"
        case nextEpisode = "next_episode"
        case lastEpisode = "last_episode"
    }
}

struct ProgressEpisode: Codable {
    let season: Int
    let number: Int
    let title: String?
    let ids: EpisodeIds
    let firstAired: Date?

    enum CodingKeys: String, CodingKey {
        case season
        case number
        case title
        case ids
        case firstAired = "first_aired"
    }
}

// MARK: - Hidden Shows

struct HiddenShow: Codable {
    let hiddenAt: Date
    let show: Show

    enum CodingKeys: String, CodingKey {
        case hiddenAt = "hidden_at"
        case show
    }
}
