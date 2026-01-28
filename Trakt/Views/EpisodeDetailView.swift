//
//  EpisodeDetailView.swift
//  Trakt
//

import SwiftUI

struct EpisodeDetailView: View {
    let group: EpisodeGroup

    @State private var posterURL: URL?
    @State private var backdropURL: URL?
    @State private var overview: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerImage

                VStack(alignment: .leading, spacing: 16) {
                    // Episode info
                    VStack(alignment: .leading, spacing: 12) {
                        if group.episodes.count == 1 {
                            singleEpisodeInfo
                        } else {
                            multipleEpisodesInfo
                        }
                    }

                    Divider()

                    // Show title and year
                    NavigationLink(value: group.show) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.show.title)
                                    .font(.headline)

                                if let year = group.show.year {
                                    Text(String(year))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    // Overview
                    if let overview = overview, !overview.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sinopsis")
                                .font(.headline)

                            Text(overview)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Show.self) { show in
            ShowDetailView(show: show)
        }
        .task {
            await loadImages()
            await loadEpisodeDetails()
        }
    }

    // MARK: - Header Image

    @ViewBuilder
    private var headerImage: some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .global).minY
            let height: CGFloat = 250
            let adjustedHeight = height + (minY > 0 ? minY : 0)

            AsyncImage(url: backdropURL ?? posterURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty, .failure:
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "tv")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)
                        }
                @unknown default:
                    Color.clear
                }
            }
            .frame(width: geometry.size.width, height: adjustedHeight)
            .clipped()
            .offset(y: minY > 0 ? -minY : 0)
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
            }
        }
        .frame(height: 250)
    }

    // MARK: - Single Episode Info

    private var singleEpisodeInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(group.episodeCode, systemImage: "play.rectangle")
                    .font(.headline)

                Spacer()

                Label(formattedDate(group.firstAired), systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let title = group.episodeTitle {
                Text(title)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    // MARK: - Multiple Episodes Info

    private var multipleEpisodesInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(group.episodeCode, systemImage: "play.rectangle")
                    .font(.headline)

                Spacer()

                Text("\(group.episodeCount) episodios")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            ForEach(group.episodes) { entry in
                HStack {
                    Text(entry.episode.episodeCode)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(width: 70, alignment: .leading)

                    if let title = entry.episode.title {
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(formattedShortDate(entry.firstAired))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }

    private func formattedShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }

    // MARK: - Data Loading

    private func loadImages() async {
        guard let tmdbId = group.show.ids.tmdb else { return }

        posterURL = await ImageService.shared.getPosterURL(for: tmdbId, size: "w342")
        backdropURL = await ImageService.shared.getBackdropURL(for: tmdbId)
    }

    private func loadEpisodeDetails() async {
        guard let tmdbId = group.show.ids.tmdb,
              let firstEpisode = group.episodes.first?.episode else { return }

        overview = await ImageService.shared.getEpisodeOverview(
            showId: tmdbId,
            season: firstEpisode.season,
            episode: firstEpisode.number
        )
    }
}

#Preview {
    NavigationStack {
        let show = Show(
            title: "The Last of Us",
            year: 2023,
            ids: ShowIds(trakt: 1, slug: "the-last-of-us", tvdb: nil, imdb: nil, tmdb: 100088)
        )
        let episode = Episode(
            season: 2,
            number: 1,
            title: "Años",
            ids: EpisodeIds(trakt: 1, tvdb: nil, imdb: nil, tmdb: nil)
        )
        let entry = CalendarEntry(firstAired: Date(), episode: episode, show: show)
        let group = EpisodeGroup(show: show, season: 2, episodes: [entry])

        EpisodeDetailView(group: group)
    }
}
