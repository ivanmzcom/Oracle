//
//  ImageService.swift
//  Trakt
//

import Foundation

actor ImageService {
    static let shared = ImageService()

    private var cache: [Int: String] = [:] // tmdbId -> posterPath

    func getPosterURL(for tmdbId: Int?, size: String = "w154") async -> URL? {
        guard let tmdbId = tmdbId else { return nil }

        if let cachedPath = cache[tmdbId] {
            return TMDBConfig.posterURL(path: cachedPath, size: size)
        }

        do {
            let posterPath = try await fetchPosterPath(tmdbId: tmdbId)
            cache[tmdbId] = posterPath
            return TMDBConfig.posterURL(path: posterPath, size: size)
        } catch {
            return nil
        }
    }

    private func fetchPosterPath(tmdbId: Int) async throws -> String {
        guard let url = URL(string: "\(TMDBConfig.baseURL)/tv/\(tmdbId)") else {
            throw ImageError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(TMDBConfig.apiKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TMDBShowResponse.self, from: data)

        guard let posterPath = response.posterPath else {
            throw ImageError.noPoster
        }

        return posterPath
    }
}

enum ImageError: Error {
    case invalidURL
    case noPoster
}

struct TMDBShowResponse: Decodable {
    let posterPath: String?

    enum CodingKeys: String, CodingKey {
        case posterPath = "poster_path"
    }
}
