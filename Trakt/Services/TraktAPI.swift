//
//  TraktAPI.swift
//  Trakt
//

import Foundation

class TraktAPI {
    private let authManager: AuthManager

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    // MARK: - Calendar Endpoints

    func getCalendarShows(startDate: Date = Date(), days: Int = 33) async throws -> [CalendarEntry] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: startDate)

        let endpoint = "\(TraktConfig.Endpoints.calendarShows)/\(dateString)/\(days)"
        return try await request(endpoint: endpoint)
    }

    func getUpNextEpisodes() async throws -> [CalendarEntry] {
        // Get calendar shows from the past year - this automatically filters dropped shows
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let dateString = formatter.string(from: startDate)

        let calendarEntries: [CalendarEntry] = try await request(
            endpoint: "\(TraktConfig.Endpoints.calendarShows)/\(dateString)/365"
        )

        // Get unique shows from calendar (these are the active/non-dropped shows)
        var seenShows = Set<Int>()
        var activeShows: [Show] = []
        for entry in calendarEntries {
            if !seenShows.contains(entry.show.ids.trakt) {
                seenShows.insert(entry.show.ids.trakt)
                activeShows.append(entry.show)
            }
        }

        // Get progress for each active show concurrently
        let upNextEntries = try await withThrowingTaskGroup(of: CalendarEntry?.self) { group in
            for show in activeShows {
                group.addTask {
                    try await self.getUpNextForShow(show)
                }
            }

            var results: [CalendarEntry] = []
            for try await entry in group {
                if let entry = entry {
                    results.append(entry)
                }
            }
            return results
        }

        // Sort by air date and filter out specials (S00)
        return upNextEntries
            .filter { $0.episode.season > 0 }
            .sorted { $0.firstAired < $1.firstAired }
    }

    private func getUpNextForShow(_ show: Show) async throws -> CalendarEntry? {
        let endpoint = "/shows/\(show.ids.trakt)/progress/watched"

        do {
            let progress: ShowProgress = try await request(endpoint: endpoint)

            // Check if there's a next episode and it has already aired
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

            return CalendarEntry(firstAired: firstAired, episode: episode, show: show)
        } catch {
            // If we can't get progress for a show, just skip it
            return nil
        }
    }

    func getUpcomingEpisodes() async throws -> [CalendarEntry] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // Get episodes from today onwards
        let dateString = formatter.string(from: Date())

        let endpoint = "\(TraktConfig.Endpoints.calendarShows)/\(dateString)/30"
        let entries: [CalendarEntry] = try await request(endpoint: endpoint)

        // Filter to only episodes that haven't aired yet
        let now = Date()
        return entries.filter { $0.firstAired >= now }
    }

    // MARK: - History

    func getWatchHistory(page: Int = 1, limit: Int = 50) async throws -> [HistoryEntry] {
        let endpoint = "/users/me/history/episodes?page=\(page)&limit=\(limit)"
        return try await request(endpoint: endpoint)
    }

    func removeFromHistory(historyId: Int) async throws {
        let endpoint = "/sync/history/remove"
        let body: [String: [Int]] = ["ids": [historyId]]
        let _: HistoryRemoveResponse = try await postRequest(endpoint: endpoint, body: body)
    }

    // MARK: - User

    func getUserSettings() async throws -> TraktUser {
        let settings: UserSettings = try await request(endpoint: "/users/settings")
        return settings.user
    }

    // MARK: - Network Request

    private func request<T: Decodable>(endpoint: String) async throws -> T {
        guard let accessToken = await authManager.getValidAccessToken() else {
            throw TraktError.notAuthenticated
        }

        guard let url = URL(string: "\(TraktConfig.baseURL)\(endpoint)") else {
            throw TraktError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(TraktConfig.apiVersion, forHTTPHeaderField: "trakt-api-version")
        request.setValue(TraktConfig.clientId, forHTTPHeaderField: "trakt-api-key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TraktError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)

        case 401:
            throw TraktError.notAuthenticated

        case 404:
            throw TraktError.notFound

        default:
            throw TraktError.serverError(httpResponse.statusCode)
        }
    }

    private func postRequest<T: Decodable, B: Encodable>(endpoint: String, body: B) async throws -> T {
        guard let accessToken = await authManager.getValidAccessToken() else {
            throw TraktError.notAuthenticated
        }

        guard let url = URL(string: "\(TraktConfig.baseURL)\(endpoint)") else {
            throw TraktError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(TraktConfig.apiVersion, forHTTPHeaderField: "trakt-api-version")
        request.setValue(TraktConfig.clientId, forHTTPHeaderField: "trakt-api-key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TraktError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)

        case 401:
            throw TraktError.notAuthenticated

        case 404:
            throw TraktError.notFound

        default:
            throw TraktError.serverError(httpResponse.statusCode)
        }
    }
}

// MARK: - Response Models

struct HistoryRemoveResponse: Decodable {
    let deleted: HistoryDeletedCount
    let notFound: HistoryNotFound

    enum CodingKeys: String, CodingKey {
        case deleted
        case notFound = "not_found"
    }
}

struct HistoryDeletedCount: Decodable {
    let movies: Int
    let episodes: Int
}

struct HistoryNotFound: Decodable {
    let ids: [Int]
}

enum TraktError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case notFound
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No autenticado. Inicia sesión en Trakt."
        case .invalidURL:
            return "URL inválida"
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .notFound:
            return "Recurso no encontrado"
        case .serverError(let code):
            return "Error del servidor: \(code)"
        }
    }
}
