//
//  ImageService.swift
//  Trakt
//

import Foundation

actor ImageService {
    static let shared = ImageService()

    private var showCache: [Int: TMDBShowResponse] = [:]
    private var episodeCache: [String: TMDBEpisodeResponse] = [:]

    // MARK: - Show Images

    func getPosterURL(for tmdbId: Int?, size: String = "w154") async -> URL? {
        guard let tmdbId = tmdbId else { return nil }

        let show = await fetchShowDetails(tmdbId: tmdbId)
        guard let posterPath = show?.posterPath else { return nil }

        return URL(string: "\(TMDBConfig.imageBaseURL)/\(size)\(posterPath)")
    }

    func getBackdropURL(for tmdbId: Int?, size: String = "w780") async -> URL? {
        guard let tmdbId = tmdbId else { return nil }

        let show = await fetchShowDetails(tmdbId: tmdbId)
        guard let backdropPath = show?.backdropPath else { return nil }

        return URL(string: "\(TMDBConfig.imageBaseURL)/\(size)\(backdropPath)")
    }

    // MARK: - Episode Details

    func getEpisodeOverview(showId: Int, season: Int, episode: Int) async -> String? {
        let episodeDetails = await fetchEpisodeDetails(showId: showId, season: season, episode: episode)
        return episodeDetails?.overview
    }

    func getEpisodeStillURL(showId: Int, season: Int, episode: Int, size: String = "w300") async -> URL? {
        let episodeDetails = await fetchEpisodeDetails(showId: showId, season: season, episode: episode)
        guard let stillPath = episodeDetails?.stillPath else { return nil }

        return URL(string: "\(TMDBConfig.imageBaseURL)/\(size)\(stillPath)")
    }

    // MARK: - Fetching

    private func fetchShowDetails(tmdbId: Int) async -> TMDBShowResponse? {
        if let cached = showCache[tmdbId] {
            return cached
        }

        guard let url = URL(string: "\(TMDBConfig.baseURL)/tv/\(tmdbId)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(TMDBConfig.apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TMDBShowResponse.self, from: data)
            showCache[tmdbId] = response
            return response
        } catch {
            return nil
        }
    }

    private func fetchEpisodeDetails(showId: Int, season: Int, episode: Int) async -> TMDBEpisodeResponse? {
        let cacheKey = "\(showId)-\(season)-\(episode)"

        if let cached = episodeCache[cacheKey] {
            return cached
        }

        guard let url = URL(string: "\(TMDBConfig.baseURL)/tv/\(showId)/season/\(season)/episode/\(episode)?language=es-ES") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(TMDBConfig.apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TMDBEpisodeResponse.self, from: data)
            episodeCache[cacheKey] = response
            return response
        } catch {
            return nil
        }
    }
}

enum ImageError: Error {
    case invalidURL
    case noPoster
}

struct TMDBShowResponse: Decodable {
    let posterPath: String?
    let backdropPath: String?
    let overview: String?

    enum CodingKeys: String, CodingKey {
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case overview
    }
}

struct TMDBEpisodeResponse: Decodable {
    let name: String?
    let overview: String?
    let stillPath: String?
    let airDate: String?
    let voteAverage: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case overview
        case stillPath = "still_path"
        case airDate = "air_date"
        case voteAverage = "vote_average"
    }
}
