//
//  EpisodeRowView.swift
//  Trakt
//

import SwiftUI

struct EpisodeRowView: View {
    let group: EpisodeGroup

    @State private var posterURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: posterURL) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .overlay {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                case .failure:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "tv")
                                .foregroundStyle(.secondary)
                        }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 44, height: 66)
            .clipped()
            .overlay(alignment: .topLeading) {
                if group.unwatchedCount > 1 {
                    Text("\(group.unwatchedCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.red, in: Capsule())
                        .offset(x: -8, y: -8)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(group.show.title)
                    .font(.headline)

                HStack {
                    Text(group.episodeCode)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let title = group.episodeTitle {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else if group.episodeCount > 1 {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("\(group.episodeCount) episodios")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .task {
            posterURL = await ImageService.shared.getPosterURL(for: group.show.ids.tmdb)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: group.firstAired)
    }
}

#Preview("Single Episode") {
    let show = Show(
        title: "The Last of Us",
        year: 2023,
        ids: ShowIds(trakt: 1, slug: "the-last-of-us", tvdb: nil, imdb: nil, tmdb: nil)
    )
    let episode = Episode(
        season: 2,
        number: 5,
        title: "Endure and Survive",
        ids: EpisodeIds(trakt: 1, tvdb: nil, imdb: nil, tmdb: nil)
    )
    let entry = CalendarEntry(firstAired: Date(), episode: episode, show: show)
    let group = EpisodeGroup(show: show, season: 2, episodes: [entry])

    return EpisodeRowView(group: group)
        .padding()
}

#Preview("Multiple Episodes") {
    let show = Show(
        title: "Jujutsu Kaisen",
        year: 2020,
        ids: ShowIds(trakt: 2, slug: "jujutsu-kaisen", tvdb: nil, imdb: nil, tmdb: nil)
    )
    let episodes = (2...4).map { num in
        CalendarEntry(
            firstAired: Date(),
            episode: Episode(
                season: 1,
                number: num,
                title: "Episode \(num)",
                ids: EpisodeIds(trakt: num, tvdb: nil, imdb: nil, tmdb: nil)
            ),
            show: show
        )
    }
    let group = EpisodeGroup(show: show, season: 1, episodes: episodes)

    return EpisodeRowView(group: group)
        .padding()
}
