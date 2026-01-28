//
//  WatchEpisodeRow.swift
//  OracleWatch
//

import SwiftUI

struct WatchEpisodeRow: View {
    let group: EpisodeGroup
    var showDate: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(group.show.title)
                    .font(.headline)
                    .lineLimit(2)

                Spacer()

                if group.unwatchedCount > 1 {
                    Text("\(group.unwatchedCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.red, in: Capsule())
                }
            }

            HStack {
                Text(group.episodeCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let title = group.episodeTitle {
                    Text("• \(title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if showDate {
                Text(formattedDate(group.firstAired))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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

    return List {
        WatchEpisodeRow(group: group)
        WatchEpisodeRow(group: group, showDate: true)
    }
}
