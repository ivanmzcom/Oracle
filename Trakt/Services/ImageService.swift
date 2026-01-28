//
//  ImageService.swift
//  Trakt
//

import Foundation

actor ImageService {
    static let shared = ImageService()

    private var episodeCache: [String: TMDBEpisodeResponse] = [:]

    // MARK: - Show Images (using shared cache)

    func getPosterURL(for tmdbId: Int?, size: String = "w154") async -> URL? {
        guard let tmdbId = tmdbId else { return nil }
        return await ImageCache.shared.getPosterURL(tmdbId: tmdbId, size: size)
    }

    func getBackdropURL(for tmdbId: Int?, size: String = "w780") async -> URL? {
        guard let tmdbId = tmdbId else { return nil }
        return await ImageCache.shared.getBackdropURL(tmdbId: tmdbId, size: size)
    }

    func getPosterData(for tmdbId: Int?, size: String = "w154") async -> Data? {
        guard let tmdbId = tmdbId else { return nil }
        return await ImageCache.shared.getPosterData(tmdbId: tmdbId, size: size)
    }

    // MARK: - Show Details

    func getShowOverview(showId: Int) async -> String? {
        let showDetails = await fetchShowDetails(showId: showId)
        return showDetails?.overview
    }

    private func fetchShowDetails(showId: Int) async -> TMDBShowResponse? {
        let sharedDefaults = UserDefaults(suiteName: "group.com.ivanmz.Trakt")
        guard let apiKey = sharedDefaults?.string(forKey: "tmdb_api_key") else {
            return nil
        }

        guard let url = URL(string: "https://api.themoviedb.org/3/tv/\(showId)?language=es-ES") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(TMDBShowResponse.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Episode Details

    func getEpisodeOverview(showId: Int, season: Int, episode: Int) async -> String? {
        let episodeDetails = await fetchEpisodeDetails(showId: showId, season: season, episode: episode)
        return episodeDetails?.overview
    }

    func getEpisodeStillURL(showId: Int, season: Int, episode: Int, size: String = "w300") async -> URL? {
        let episodeDetails = await fetchEpisodeDetails(showId: showId, season: season, episode: episode)
        guard let stillPath = episodeDetails?.stillPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(stillPath)")
    }

    // MARK: - Episode Fetching

    private func fetchEpisodeDetails(showId: Int, season: Int, episode: Int) async -> TMDBEpisodeResponse? {
        let cacheKey = "\(showId)-\(season)-\(episode)"

        if let cached = episodeCache[cacheKey] {
            return cached
        }

        let sharedDefaults = UserDefaults(suiteName: "group.com.ivanmz.Trakt")
        guard let apiKey = sharedDefaults?.string(forKey: "tmdb_api_key") else {
            return nil
        }

        guard let url = URL(string: "https://api.themoviedb.org/3/tv/\(showId)/season/\(season)/episode/\(episode)?language=es-ES") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

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

// MARK: - Response Models

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
