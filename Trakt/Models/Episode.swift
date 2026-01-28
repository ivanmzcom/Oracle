//
//  Episode.swift
//  Trakt
//

import Foundation

struct Episode: Codable, Identifiable {
    let season: Int
    let number: Int
    let title: String?
    let ids: EpisodeIds

    var id: Int { ids.trakt }

    var episodeCode: String {
        String(format: "S%02dE%02d", season, number)
    }
}

struct EpisodeIds: Codable {
    let trakt: Int
    let tvdb: Int?
    let imdb: String?
    let tmdb: Int?
}

struct CalendarEntry: Codable, Identifiable {
    let firstAired: Date
    let episode: Episode
    let show: Show
    var unwatchedCount: Int?

    var id: String {
        "\(show.id)-\(episode.id)"
    }

    enum CodingKeys: String, CodingKey {
        case firstAired = "first_aired"
        case episode
        case show
    }
}

// MARK: - Episode Group (for consecutive episodes)

struct EpisodeGroup: Identifiable, Hashable {
    let show: Show
    let season: Int
    let episodes: [CalendarEntry]

    var id: String {
        "\(show.id)-\(season)-\(episodes.first?.episode.number ?? 0)"
    }

    static func == (lhs: EpisodeGroup, rhs: EpisodeGroup) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var firstAired: Date {
        episodes.first?.firstAired ?? Date()
    }

    var episodeCode: String {
        guard let first = episodes.first?.episode.number,
              let last = episodes.last?.episode.number else {
            return "S\(String(format: "%02d", season))"
        }

        if first == last {
            return String(format: "S%02dE%02d", season, first)
        } else {
            return String(format: "S%02dE%02d-%d", season, first, last)
        }
    }

    var episodeTitle: String? {
        if episodes.count == 1 {
            return episodes.first?.episode.title
        }
        return nil
    }

    var episodeCount: Int {
        episodes.count
    }

    var unwatchedCount: Int {
        episodes.first?.unwatchedCount ?? episodes.count
    }
}

// MARK: - Grouping Helper

extension Array where Element == CalendarEntry {
    func asIndividualGroups() -> [EpisodeGroup] {
        self.sorted { $0.firstAired < $1.firstAired }
            .map { entry in
                EpisodeGroup(
                    show: entry.show,
                    season: entry.episode.season,
                    episodes: [entry]
                )
            }
    }

    func groupedByShowAndSeason() -> [EpisodeGroup] {
        // Sort by show, season, and episode number
        let sorted = self.sorted {
            if $0.show.id != $1.show.id {
                return $0.show.title < $1.show.title
            }
            if $0.episode.season != $1.episode.season {
                return $0.episode.season < $1.episode.season
            }
            return $0.episode.number < $1.episode.number
        }

        var groups: [EpisodeGroup] = []
        var currentGroup: [CalendarEntry] = []

        for entry in sorted {
            if let last = currentGroup.last {
                // Check if this episode is consecutive (same show, same season, next episode)
                let sameShow = last.show.id == entry.show.id
                let sameSeason = last.episode.season == entry.episode.season
                let consecutive = entry.episode.number == last.episode.number + 1

                if sameShow && sameSeason && consecutive {
                    currentGroup.append(entry)
                } else {
                    // Save current group and start new one
                    if !currentGroup.isEmpty {
                        groups.append(EpisodeGroup(
                            show: last.show,
                            season: last.episode.season,
                            episodes: currentGroup
                        ))
                    }
                    currentGroup = [entry]
                }
            } else {
                currentGroup = [entry]
            }
        }

        // Don't forget the last group
        if let last = currentGroup.last, !currentGroup.isEmpty {
            groups.append(EpisodeGroup(
                show: last.show,
                season: last.episode.season,
                episodes: currentGroup
            ))
        }

        // Sort groups by first aired date
        return groups.sorted { $0.firstAired < $1.firstAired }
    }
}

// MARK: - History Entry

struct HistoryEntry: Codable, Identifiable {
    let id: Int
    let watchedAt: Date
    let action: String
    let type: String
    let episode: Episode
    let show: Show

    enum CodingKeys: String, CodingKey {
        case id
        case watchedAt = "watched_at"
        case action
        case type
        case episode
        case show
    }
}

// MARK: - History Grouping Helper

extension Array where Element == HistoryEntry {
    func asHistoryGroups() -> [EpisodeGroup] {
        // Convert history entries to calendar entries for reuse of EpisodeGroup
        let calendarEntries = self.map { entry in
            CalendarEntry(
                firstAired: entry.watchedAt,
                episode: entry.episode,
                show: entry.show
            )
        }
        return calendarEntries.asIndividualGroups()
    }
}