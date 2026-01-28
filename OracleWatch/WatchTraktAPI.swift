//
//  WatchTraktAPI.swift
//  Shared API client for watchOS
//

import Foundation

actor WatchTraktAPI {
    private let sharedDefaults = UserDefaults(suiteName: "group.com.ivanmz.Trakt")
    private let baseURL = "https://api.trakt.tv"
    private let apiVersion = "2"

    private var accessToken: String? {
        sharedDefaults?.string(forKey: "trakt_access_token")
    }

    private var clientId: String? {
        sharedDefaults?.string(forKey: "trakt_client_id")
    }

    var isAuthenticated: Bool {
        accessToken != nil && clientId != nil
    }

    // MARK: - Up Next Episodes

    func getUpNextEpisodes() async throws -> [CalendarEntry] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let dateString = formatter.string(from: startDate)

        let calendarEntries: [CalendarEntry] = try await request(
            endpoint: "/calendars/my/shows/\(dateString)/365"
        )

        var seenShows = Set<Int>()
        var activeShows: [Show] = []

        for entry in calendarEntries {
            if !seenShows.contains(entry.show.ids.trakt) {
                seenShows.insert(entry.show.ids.trakt)
                activeShows.append(entry.show)
            }
        }

        let upNextEntries = await withTaskGroup(of: CalendarEntry?.self) { group in
            for show in activeShows {
                group.addTask {
                    try? await self.getUpNextForShow(show)
                }
            }

            var results: [CalendarEntry] = []
            for await entry in group {
                if let entry = entry {
                    results.append(entry)
                }
            }
            return results
        }

        return upNextEntries
            .filter { $0.episode.season > 0 }
            .sorted { $0.firstAired < $1.firstAired }
    }

    private func getUpNextForShow(_ show: Show) async throws -> CalendarEntry? {
        let progress: ShowProgress = try await request(
            endpoint: "/shows/\(show.ids.trakt)/progress/watched"
        )

        guard let nextEpisode = progress.nextEpisode,
              let firstAired = nextEpisode.firstAired,
              firstAired < Date() else {
            return nil
        }

        let episode = Episode(
            season: nextEpisode.season,
            number: nextEpisode.number,
            title: nextEpisode.title,
            ids: nextEpisode.ids
        )

        let unwatchedCount = progress.aired - progress.completed

        var entry = CalendarEntry(firstAired: firstAired, episode: episode, show: show)
        entry.unwatchedCount = unwatchedCount
        return entry
    }

    // MARK: - Upcoming Episodes

    func getUpcomingEpisodes() async throws -> [CalendarEntry] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())

        let entries: [CalendarEntry] = try await request(
            endpoint: "/calendars/my/shows/\(dateString)/30"
        )

        let now = Date()
        return entries.filter { $0.firstAired >= now }
    }

    // MARK: - History

    func getWatchHistory(limit: Int = 30) async throws -> [HistoryEntry] {
        return try await request(endpoint: "/users/me/history/episodes?limit=\(limit)")
    }

    // MARK: - Search

    func searchShows(query: String) async throws -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await request(endpoint: "/search/show?query=\(encodedQuery)&limit=15")
    }

    // MARK: - Show Details

    func getShowProgress(showId: Int) async throws -> ShowProgress {
        return try await request(endpoint: "/shows/\(showId)/progress/watched")
    }

    // MARK: - Network Request

    private func request<T: Decodable>(endpoint: String) async throws -> T {
        guard let accessToken = accessToken, let clientId = clientId else {
            throw WatchTraktError.notAuthenticated
        }

        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw WatchTraktError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiVersion, forHTTPHeaderField: "trakt-api-version")
        request.setValue(clientId, forHTTPHeaderField: "trakt-api-key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WatchTraktError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        case 401:
            throw WatchTraktError.notAuthenticated
        case 404:
            throw WatchTraktError.notFound
        default:
            throw WatchTraktError.serverError(httpResponse.statusCode)
        }
    }
}

enum WatchTraktError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case notFound
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "api.error.notauthenticated")
        case .invalidURL:
            return String(localized: "api.error.invalidurl")
        case .invalidResponse:
            return String(localized: "api.error.invalidresponse")
        case .notFound:
            return String(localized: "api.error.notfound")
        case .serverError(let code):
            return String(localized: "api.error.server", defaultValue: "Server error: \(code)")
        }
    }
}

// Reuse SearchResult from the main app
struct SearchResult: Decodable, Identifiable {
    let type: String
    let score: Double?
    let show: Show

    var id: Int { show.id }
}
