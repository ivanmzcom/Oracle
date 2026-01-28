//
//  AppIntents.swift
//  Trakt
//

import AppIntents
import SwiftUI
import UIKit

// MARK: - Up Next Intent

struct GetUpNextIntent: AppIntent {
    static var title: LocalizedStringResource = "See Up Next"
    static var description = IntentDescription("Shows episodes available to watch now")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<[EpisodeEntity]> & ShowsSnippetView {
        let episodes = try await fetchUpNextEpisodes()

        if episodes.isEmpty {
            return .result(
                value: [],
                view: EmptyEpisodesView(message: String(localized: "intent.upnext.empty"))
            )
        }

        return .result(
            value: episodes,
            view: EpisodesSnippetView(title: String(localized: "intent.shortcut.upnext"), episodes: Array(episodes.prefix(5)))
        )
    }

    private func fetchUpNextEpisodes() async throws -> [EpisodeEntity] {
        let sharedDefaults = UserDefaults(suiteName: "group.com.ivanmz.Trakt")

        guard let accessToken = sharedDefaults?.string(forKey: "trakt_access_token"),
              let clientId = sharedDefaults?.string(forKey: "trakt_client_id") else {
            throw IntentError.notAuthenticated
        }

        // Use calendar from past year to find active (non-dropped) shows
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let dateString = formatter.string(from: startDate)

        guard let calendarUrl = URL(string: "https://api.trakt.tv/calendars/my/shows/\(dateString)/365") else {
            throw IntentError.invalidURL
        }

        var calendarRequest = URLRequest(url: calendarUrl)
        calendarRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        calendarRequest.setValue("2", forHTTPHeaderField: "trakt-api-version")
        calendarRequest.setValue(clientId, forHTTPHeaderField: "trakt-api-key")
        calendarRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (calendarData, _) = try await URLSession.shared.data(for: calendarRequest)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let calendarEntries = try decoder.decode([IntentCalendarEntry].self, from: calendarData)

        // Get unique active shows from calendar
        var seenShows = Set<Int>()
        var activeShows: [(id: Int, title: String, tmdbId: Int?)] = []
        for entry in calendarEntries {
            if !seenShows.contains(entry.show.ids.trakt) {
                seenShows.insert(entry.show.ids.trakt)
                activeShows.append((entry.show.ids.trakt, entry.show.title, entry.show.ids.tmdb))
            }
        }

        // Get progress for each active show concurrently
        let episodes = await withTaskGroup(of: EpisodeEntity?.self) { group in
            for show in activeShows {
                group.addTask {
                    try? await self.fetchUpNextForShow(
                        showId: show.id,
                        showTitle: show.title,
                        tmdbId: show.tmdbId,
                        accessToken: accessToken,
                        clientId: clientId
                    )
                }
            }

            var results: [EpisodeEntity] = []
            for await episode in group {
                if let episode = episode {
                    results.append(episode)
                }
            }
            return results
        }

        return episodes.sorted { $0.airDate < $1.airDate }
    }

    private func fetchUpNextForShow(showId: Int, showTitle: String, tmdbId: Int?, accessToken: String, clientId: String) async throws -> EpisodeEntity? {
        guard let url = URL(string: "https://api.trakt.tv/shows/\(showId)/progress/watched") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2", forHTTPHeaderField: "trakt-api-version")
        request.setValue(clientId, forHTTPHeaderField: "trakt-api-key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let progress = try decoder.decode(IntentShowProgress.self, from: data)

        guard let nextEpisode = progress.nextEpisode,
              let airDate = nextEpisode.firstAired,
              airDate < Date() else {
            return nil
        }

        // Fetch poster image using shared cache
        var posterData: Data? = nil
        if let tmdbId = tmdbId {
            posterData = await ImageCache.shared.getPosterData(tmdbId: tmdbId)
        }

        return EpisodeEntity(
            id: "\(showId)-\(nextEpisode.season)-\(nextEpisode.number)",
            showTitle: showTitle,
            episodeCode: String(format: "S%02dE%02d", nextEpisode.season, nextEpisode.number),
            episodeTitle: nextEpisode.title,
            airDate: airDate,
            posterData: posterData
        )
    }
}

// MARK: - Upcoming Intent

struct GetUpcomingIntent: AppIntent {
    static var title: LocalizedStringResource = "See Upcoming Episodes"
    static var description = IntentDescription("Shows episodes that will air soon")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<[EpisodeEntity]> & ShowsSnippetView {
        let episodes = try await fetchUpcomingEpisodes()

        if episodes.isEmpty {
            return .result(
                value: [],
                view: EmptyEpisodesView(message: String(localized: "intent.upcoming.empty"))
            )
        }

        return .result(
            value: episodes,
            view: EpisodesSnippetView(title: String(localized: "intent.shortcut.upcoming"), episodes: Array(episodes.prefix(5)))
        )
    }

    private func fetchUpcomingEpisodes() async throws -> [EpisodeEntity] {
        let sharedDefaults = UserDefaults(suiteName: "group.com.ivanmz.Trakt")

        guard let accessToken = sharedDefaults?.string(forKey: "trakt_access_token"),
              let clientId = sharedDefaults?.string(forKey: "trakt_client_id") else {
            throw IntentError.notAuthenticated
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())

        guard let url = URL(string: "https://api.trakt.tv/calendars/my/shows/\(dateString)/30") else {
            throw IntentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2", forHTTPHeaderField: "trakt-api-version")
        request.setValue(clientId, forHTTPHeaderField: "trakt-api-key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([IntentCalendarEntry].self, from: data)

        let now = Date()
        let upcomingEntries = entries.filter { $0.firstAired >= now }

        // Fetch poster images concurrently using shared cache
        let episodes = await withTaskGroup(of: EpisodeEntity.self) { group in
            for entry in upcomingEntries.prefix(10) {
                group.addTask {
                    var posterData: Data? = nil
                    if let tmdbId = entry.show.ids.tmdb {
                        posterData = await ImageCache.shared.getPosterData(tmdbId: tmdbId)
                    }
                    return EpisodeEntity(
                        id: "\(entry.show.ids.trakt)-\(entry.episode.season)-\(entry.episode.number)",
                        showTitle: entry.show.title,
                        episodeCode: String(format: "S%02dE%02d", entry.episode.season, entry.episode.number),
                        episodeTitle: entry.episode.title,
                        airDate: entry.firstAired,
                        posterData: posterData
                    )
                }
            }

            var results: [EpisodeEntity] = []
            for await episode in group {
                results.append(episode)
            }
            return results
        }

        return episodes.sorted { $0.airDate < $1.airDate }
    }
}

// MARK: - Episode Entity

struct EpisodeEntity: AppEntity {
    let id: String
    let showTitle: String
    let episodeCode: String
    let episodeTitle: String?
    let airDate: Date
    let posterData: Data?

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Episode"

    static var defaultQuery = EpisodeEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(showTitle)",
            subtitle: "\(episodeCode)\(episodeTitle.map { " - \($0)" } ?? "")"
        )
    }

    var posterImage: Image? {
        guard let data = posterData,
              let uiImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
}

struct EpisodeEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [EpisodeEntity] {
        []
    }

    func suggestedEntities() async throws -> [EpisodeEntity] {
        []
    }
}

// MARK: - App Shortcuts Provider

struct TraktShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetUpNextIntent(),
            phrases: [
                "See Up Next in \(.applicationName)",
                "What can I watch in \(.applicationName)",
                "Available episodes in \(.applicationName)"
            ],
            shortTitle: "Up Next",
            systemImageName: "play.circle"
        )

        AppShortcut(
            intent: GetUpcomingIntent(),
            phrases: [
                "See upcoming episodes in \(.applicationName)",
                "What episodes are coming in \(.applicationName)",
                "Calendar for \(.applicationName)"
            ],
            shortTitle: "Upcoming",
            systemImageName: "calendar"
        )
    }
}

// MARK: - Intent Models

private struct IntentCalendarEntry: Decodable {
    let firstAired: Date
    let episode: IntentEpisode
    let show: IntentShow

    enum CodingKeys: String, CodingKey {
        case firstAired = "first_aired"
        case episode
        case show
    }
}

private struct IntentEpisode: Decodable {
    let season: Int
    let number: Int
    let title: String?
}

private struct IntentShow: Decodable {
    let title: String
    let ids: IntentShowIds
}

private struct IntentShowIds: Decodable {
    let trakt: Int
    let tmdb: Int?
}

private struct IntentWatchedShow: Decodable {
    let show: IntentShow
}

private struct IntentShowProgress: Decodable {
    let nextEpisode: IntentProgressEpisode?

    enum CodingKeys: String, CodingKey {
        case nextEpisode = "next_episode"
    }
}

private struct IntentProgressEpisode: Decodable {
    let season: Int
    let number: Int
    let title: String?
    let firstAired: Date?

    enum CodingKeys: String, CodingKey {
        case season
        case number
        case title
        case firstAired = "first_aired"
    }
}

// MARK: - Errors

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case notAuthenticated
    case invalidURL

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notAuthenticated:
            return "You must log in to the app first"
        case .invalidURL:
            return "Error creating request"
        }
    }
}

// MARK: - Snippet Views

struct EpisodesSnippetView: View {
    let title: String
    let episodes: [EpisodeEntity]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(String(localized: "episode.count", defaultValue: "\(episodes.count) episodes"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(episodes, id: \.id) { episode in
                HStack(spacing: 12) {
                    if let posterImage = episode.posterImage {
                        posterImage
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 66)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorForShow(episode.showTitle))
                            .frame(width: 44, height: 66)
                            .overlay {
                                Text(String(episode.showTitle.prefix(1)).uppercased())
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(episode.showTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        Text(episode.episodeCode)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let episodeTitle = episode.episodeTitle {
                            Text(episodeTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Text(formatDate(episode.airDate))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()
                }
            }
        }
        .padding()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func colorForShow(_ title: String) -> Color {
        let colors: [Color] = [.blue, .purple, .pink, .orange, .green, .teal, .indigo, .mint]
        let hash = title.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[hash % colors.count]
    }
}

struct EmptyEpisodesView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tv")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
