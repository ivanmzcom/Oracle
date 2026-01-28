//
//  SeasonDetailView.swift
//  Trakt
//

import SwiftUI

struct SeasonDetailView: View {
    @Environment(AuthManager.self) var authManager
    let show: Show
    let season: Season

    @State private var episodes: [SeasonEpisode] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var api: TraktAPI {
        TraktAPI(authManager: authManager)
    }

    var body: some View {
        Group {
            if isLoading && episodes.isEmpty {
                ProgressView("Cargando episodios...")
            } else if let error = errorMessage {
                errorView(error)
            } else {
                episodesList
            }
        }
        .navigationTitle(seasonTitle)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadEpisodes()
        }
    }

    private var seasonTitle: String {
        if season.number == 0 {
            return "Especiales"
        } else {
            return "Temporada \(season.number)"
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text("Error")
                .font(.title2)
                .fontWeight(.medium)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Reintentar") {
                Task {
                    await loadEpisodes()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Episodes List

    private var episodesList: some View {
        List {
            if let overview = season.overview, !overview.isEmpty {
                Section {
                    Text(overview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(episodes) { episode in
                    NavigationLink(value: episode) {
                        episodeRow(episode)
                    }
                }
            } header: {
                if let count = season.episodeCount {
                    Text("\(count) episodios")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: SeasonEpisode.self) { episode in
            let calendarEntry = CalendarEntry(
                firstAired: episode.firstAired ?? Date(),
                episode: episode.toEpisode(),
                show: show
            )
            let group = EpisodeGroup(show: show, season: episode.season, episodes: [calendarEntry])
            EpisodeDetailView(group: group)
        }
    }

    @ViewBuilder
    private func episodeRow(_ episode: SeasonEpisode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(format: "E%02d", episode.number))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, alignment: .leading)

                Text(episode.title ?? "Episodio \(episode.number)")
                    .font(.headline)

                Spacer()

                if let runtime = episode.runtime {
                    Text("\(runtime) min")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if let firstAired = episode.firstAired {
                Text(formattedDate(firstAired))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let overview = episode.overview, !overview.isEmpty {
                Text(overview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }

    // MARK: - Data Loading

    private func loadEpisodes() async {
        isLoading = true
        errorMessage = nil

        do {
            episodes = try await api.getSeasonEpisodes(showId: show.id, season: season.number)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        SeasonDetailView(
            show: Show(
                title: "The Last of Us",
                year: 2023,
                ids: ShowIds(trakt: 158947, slug: "the-last-of-us", tvdb: nil, imdb: nil, tmdb: 100088)
            ),
            season: Season(
                number: 1,
                ids: SeasonIds(trakt: 1, tvdb: nil, tmdb: nil),
                episodeCount: 9,
                airedEpisodes: 9,
                title: nil,
                overview: nil,
                firstAired: nil
            )
        )
        .environment(AuthManager())
    }
}
