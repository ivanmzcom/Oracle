//
//  TraktWidget.swift
//  TraktWidget
//
//  Created by Iván Moreno Zambudio on 28/1/26.
//

import WidgetKit
import SwiftUI

struct UpNextEntry: TimelineEntry {
    let date: Date
    let episodes: [WidgetEpisodeData]
    let isLoggedIn: Bool
}

struct TraktWidgetProvider: TimelineProvider {
    private let sharedDefaults = UserDefaults(suiteName: "group.com.ivanmz.Trakt")
    private let dataService = WidgetDataService()

    func placeholder(in context: Context) -> UpNextEntry {
        UpNextEntry(date: Date(), episodes: [], isLoggedIn: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (UpNextEntry) -> Void) {
        // For snapshots, use cached data for speed
        completion(makeCachedEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpNextEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func makeEntry() async -> UpNextEntry {
        let isLoggedIn = sharedDefaults?.string(forKey: "trakt_access_token") != nil

        guard isLoggedIn else {
            return UpNextEntry(date: Date(), episodes: [], isLoggedIn: false)
        }

        // Fetch fresh data from the API
        let episodes = await dataService.fetchUpcomingEpisodes()

        // Cache the results for snapshots
        if let data = try? JSONEncoder().encode(episodes) {
            sharedDefaults?.set(data, forKey: "widget_episodes")
        }

        return UpNextEntry(date: Date(), episodes: episodes, isLoggedIn: true)
    }

    private func makeCachedEntry() -> UpNextEntry {
        let isLoggedIn = sharedDefaults?.string(forKey: "trakt_access_token") != nil

        var episodes: [WidgetEpisodeData] = []
        if isLoggedIn, let data = sharedDefaults?.data(forKey: "widget_episodes") {
            episodes = (try? JSONDecoder().decode([WidgetEpisodeData].self, from: data)) ?? []
        }

        return UpNextEntry(date: Date(), episodes: episodes, isLoggedIn: isLoggedIn)
    }
}

struct TraktWidgetEntryView: View {
    var entry: UpNextEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if !entry.isLoggedIn {
            Text("Inicia sesión en Trakt")
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding()
        } else if entry.episodes.isEmpty {
            Text("No hay episodios próximos")
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.episodes.prefix(maxEpisodes)) { episode in
                    HStack(spacing: 8) {
                        if let posterURLString = episode.posterURL,
                           let posterURL = URL(string: posterURLString) {
                            AsyncImage(url: posterURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .failure, .empty:
                                    Rectangle()
                                        .fill(.quaternary)
                                        .overlay {
                                            Image(systemName: "tv")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.tertiary)
                                        }
                                @unknown default:
                                    Rectangle()
                                        .fill(.quaternary)
                                }
                            }
                            .frame(width: 28, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            Rectangle()
                                .fill(.quaternary)
                                .frame(width: 28, height: 42)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay {
                                    Image(systemName: "tv")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(episode.showTitle)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Text(episode.episodeCode)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .padding()
        }
    }

    private var maxEpisodes: Int {
        switch family {
        case .systemSmall: return 2
        case .systemMedium: return 2
        case .systemLarge: return 5
        default: return 2
        }
    }
}

struct TraktWidget: Widget {
    let kind = "TraktWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TraktWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                TraktWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                TraktWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Trakt - Próximos")
        .description("Muestra tus próximos episodios.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    TraktWidget()
} timeline: {
    UpNextEntry(date: .now, episodes: [
        WidgetEpisodeData(showTitle: "Severance", episodeCode: "S02E03", posterURL: nil),
        WidgetEpisodeData(showTitle: "The White Lotus", episodeCode: "S03E05", posterURL: nil),
    ], isLoggedIn: true)
}

#Preview(as: .systemMedium) {
    TraktWidget()
} timeline: {
    UpNextEntry(date: .now, episodes: [
        WidgetEpisodeData(showTitle: "Severance", episodeCode: "S02E03", posterURL: nil),
        WidgetEpisodeData(showTitle: "The White Lotus", episodeCode: "S03E05", posterURL: nil),
    ], isLoggedIn: true)
}

#Preview(as: .systemLarge) {
    TraktWidget()
} timeline: {
    UpNextEntry(date: .now, episodes: [
        WidgetEpisodeData(showTitle: "Severance", episodeCode: "S02E03", posterURL: nil),
        WidgetEpisodeData(showTitle: "The White Lotus", episodeCode: "S03E05", posterURL: nil),
        WidgetEpisodeData(showTitle: "The Last of Us", episodeCode: "S02E01", posterURL: nil),
        WidgetEpisodeData(showTitle: "Andor", episodeCode: "S02E01", posterURL: nil),
        WidgetEpisodeData(showTitle: "Daredevil: Born Again", episodeCode: "S01E02", posterURL: nil),
    ], isLoggedIn: true)
}
