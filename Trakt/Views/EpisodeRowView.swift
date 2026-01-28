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
            // Poster with shadow
            AsyncImage(url: posterURL) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color(.systemGray4), Color(.systemGray5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color(.systemGray4), Color(.systemGray5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Image(systemName: "tv")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 60, height: 90)
            .clipped()
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            .overlay(alignment: .topLeading) {
                if group.unwatchedCount > 1 {
                    Text("\(group.unwatchedCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(.red)
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        )
                        .offset(x: -8, y: -8)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(group.show.title)
                    .font(.headline)

                HStack(spacing: 8) {
                    // Episode code pill
                    Text(group.episodeCode)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())

                    if let title = group.episodeTitle {
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else if group.episodeCount > 1 {
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

            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
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
