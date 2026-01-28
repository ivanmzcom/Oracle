//
//  WatchEpisodeDetailView.swift
//  OracleWatch
//

import SwiftUI

struct WatchEpisodeDetailView: View {
    let group: EpisodeGroup

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Episode code
                Text(group.episodeCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Episode title
                if let title = group.episodeTitle {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                }

                Divider()

                // Show info
                NavigationLink(value: group.show) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.show.title)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if let year = group.show.year {
                                Text(String(year))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)

                Divider()

                // Air date
                VStack(alignment: .leading, spacing: 4) {
                    Text("Air Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(formattedDate(group.firstAired))
                        .font(.subheadline)
                }

                // Episode count if multiple
                if group.episodeCount > 1 {
                    Divider()

                    Text(String(localized: "episode.count", defaultValue: "\(group.episodeCount) episodes"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(group.episodes) { entry in
                        HStack {
                            Text(entry.episode.episodeCode)
                                .font(.caption)
                                .fontWeight(.medium)

                            if let title = entry.episode.title {
                                Text(title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(group.show.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Show.self) { show in
            WatchShowDetailView(show: show)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    let show = Show(
        title: "The Last of Us",
        year: 2023,
        ids: ShowIds(trakt: 1, slug: "the-last-of-us", tvdb: nil, imdb: nil, tmdb: 100088)
    )
    let episode = Episode(
        season: 2,
        number: 1,
        title: "Years",
        ids: EpisodeIds(trakt: 1, tvdb: nil, imdb: nil, tmdb: nil)
    )
    let entry = CalendarEntry(firstAired: Date(), episode: episode, show: show)
    let group = EpisodeGroup(show: show, season: 2, episodes: [entry])

    return NavigationStack {
        WatchEpisodeDetailView(group: group)
    }
}
