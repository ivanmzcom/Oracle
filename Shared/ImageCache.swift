//
//  ImageCache.swift
//  Shared - Image caching for all targets
//

import Foundation

actor ImageCache {
    static let shared = ImageCache()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL?

    private init() {
        cacheDirectory = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.ivanmz.Trakt")?
            .appendingPathComponent("ImageCache", isDirectory: true)

        // Create cache directory if needed
        if let dir = cacheDirectory, !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Public API

    /// Get poster data for a TMDB show ID, fetching from network if not cached
    func getPosterData(tmdbId: Int, size: String = "w154") async -> Data? {
        let cacheKey = "poster_\(tmdbId)_\(size)"

        // Check cache first
        if let cachedData = loadFromCache(key: cacheKey) {
            return cachedData
        }

        // Fetch from network
        guard let posterPath = await fetchPosterPath(tmdbId: tmdbId) else {
            return nil
        }

        guard let imageURL = URL(string: "https://image.tmdb.org/t/p/\(size)\(posterPath)") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            saveToCache(data: data, key: cacheKey)
            return data
        } catch {
            return nil
        }
    }

    /// Get poster URL for a TMDB show ID
    func getPosterURL(tmdbId: Int, size: String = "w154") async -> URL? {
        guard let posterPath = await fetchPosterPath(tmdbId: tmdbId) else {
            return nil
        }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(posterPath)")
    }

    /// Get backdrop URL for a TMDB show ID
    func getBackdropURL(tmdbId: Int, size: String = "w780") async -> URL? {
        guard let backdropPath = await fetchBackdropPath(tmdbId: tmdbId) else {
            return nil
        }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(backdropPath)")
    }

    /// Clear all cached images
    func clearCache() {
        guard let dir = cacheDirectory else { return }
        try? fileManager.removeItem(at: dir)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // MARK: - Cache Storage

    private func loadFromCache(key: String) -> Data? {
        guard let cacheDirectory = cacheDirectory else { return nil }
        let fileURL = cacheDirectory.appendingPathComponent(key)

        // Check if file exists and is not older than 7 days
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let modificationDate = attributes[.modificationDate] as? Date,
              Date().timeIntervalSince(modificationDate) < 7 * 24 * 60 * 60 else {
            return nil
        }

        return try? Data(contentsOf: fileURL)
    }

    private func saveToCache(data: Data, key: String) {
        guard let cacheDirectory = cacheDirectory else { return }
        let fileURL = cacheDirectory.appendingPathComponent(key)
        try? data.write(to: fileURL)
    }

    // MARK: - TMDB API

    private var showMetadataCache: [Int: TMDBMetadata] = [:]

    private struct TMDBMetadata {
        let posterPath: String?
        let backdropPath: String?
    }

    private func fetchShowMetadata(tmdbId: Int) async -> TMDBMetadata? {
        if let cached = showMetadataCache[tmdbId] {
            return cached
        }

        let sharedDefaults = UserDefaults(suiteName: "group.com.ivanmz.Trakt")
        guard let apiKey = sharedDefaults?.string(forKey: "tmdb_api_key") else {
            return nil
        }

        guard let url = URL(string: "https://api.themoviedb.org/3/tv/\(tmdbId)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(CacheTMDBResponse.self, from: data)
            let metadata = TMDBMetadata(posterPath: response.posterPath, backdropPath: response.backdropPath)
            showMetadataCache[tmdbId] = metadata
            return metadata
        } catch {
            return nil
        }
    }

    private func fetchPosterPath(tmdbId: Int) async -> String? {
        await fetchShowMetadata(tmdbId: tmdbId)?.posterPath
    }

    private func fetchBackdropPath(tmdbId: Int) async -> String? {
        await fetchShowMetadata(tmdbId: tmdbId)?.backdropPath
    }
}

// MARK: - Response Model

private struct CacheTMDBResponse: Decodable {
    let posterPath: String?
    let backdropPath: String?

    enum CodingKeys: String, CodingKey {
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }
}
