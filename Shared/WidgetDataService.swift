//
//  WidgetDataService.swift
//  Shared - Used by the widget to fetch data directly
//

import Foundation

actor WidgetDataService {
    private let sharedDefaults = UserDefaults(suiteName: "group.com.ivanmz.Trakt")

    private var traktClientId: String? {
        sharedDefaults?.string(forKey: "trakt_client_id")
    }

    private var tmdbAPIKey: String? {
        sharedDefaults?.string(forKey: "tmdb_api_key")
    }

    private var accessToken: String? {
        sharedDefaults?.string(forKey: "trakt_access_token")
    }

    // MARK: - Fetch Upcoming Episodes

    func fetchUpcomingEpisodes() async -> [WidgetEpisodeData] {
        guard let accessToken = accessToken,
              let clientId = traktClientId else {
            return []
        }

        do {
            let entries = try await fetchCalendarEntries(accessToken: accessToken, clientId: clientId)

            // Fetch poster URLs in parallel
            return await withTaskGroup(of: (Int, WidgetEpisodeData).self) { group in
                for (index, entry) in entries.prefix(10).enumerated() {
                    group.addTask {
                        let posterURL = await self.fetchPosterURL(tmdbId: entry.tmdbId)
                        return (index, WidgetEpisodeData(
                            showTitle: entry.showTitle,
                            episodeCode: entry.episodeCode,
                            posterURL: posterURL?.absoluteString
                        ))
                    }
                }

                var results: [(Int, WidgetEpisodeData)] = []
                for await result in group {
                    results.append(result)
                }
                return results.sorted { $0.0 < $1.0 }.map(\.1)
            }
        } catch {
            return []
        }
    }

    // MARK: - Trakt API

    private func fetchCalendarEntries(accessToken: String, clientId: String) async throws -> [SimpleCalendarEntry] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())

        guard let url = URL(string: "https://api.trakt.tv/calendars/my/shows/\(dateString)/30") else {
            throw WidgetDataError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2", forHTTPHeaderField: "trakt-api-version")
        request.setValue(clientId, forHTTPHeaderField: "trakt-api-key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WidgetDataError.requestFailed
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([CalendarEntryDTO].self, from: data)

        // Filter to only episodes that haven't aired yet
        let now = Date()
        return entries
            .filter { $0.firstAired >= now }
            .map { entry in
                SimpleCalendarEntry(
                    showTitle: entry.show.title,
                    episodeCode: String(format: "S%02dE%02d", entry.episode.season, entry.episode.number),
                    tmdbId: entry.show.ids.tmdb
                )
            }
    }

    // MARK: - TMDB API

    private func fetchPosterURL(tmdbId: Int?) async -> URL? {
        guard let tmdbId = tmdbId,
              let apiKey = tmdbAPIKey else {
            return nil
        }

        guard let url = URL(string: "https://api.themoviedb.org/3/tv/\(tmdbId)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TMDBResponse.self, from: data)

            if let posterPath = response.posterPath {
                return URL(string: "https://image.tmdb.org/t/p/w154\(posterPath)")
            }
        } catch {
            // Ignore errors, just return nil
        }

        return nil
    }
}

// MARK: - Private DTOs

private struct SimpleCalendarEntry {
    let showTitle: String
    let episodeCode: String
    let tmdbId: Int?
}

private struct CalendarEntryDTO: Decodable {
    let firstAired: Date
    let episode: EpisodeDTO
    let show: ShowDTO

    enum CodingKeys: String, CodingKey {
        case firstAired = "first_aired"
        case episode
        case show
    }
}

private struct EpisodeDTO: Decodable {
    let season: Int
    let number: Int
}

private struct ShowDTO: Decodable {
    let title: String
    let ids: ShowIdsDTO
}

private struct ShowIdsDTO: Decodable {
    let tmdb: Int?
}

private struct TMDBResponse: Decodable {
    let posterPath: String?

    enum CodingKeys: String, CodingKey {
        case posterPath = "poster_path"
    }
}

private enum WidgetDataError: Error {
    case invalidURL
    case requestFailed
}
