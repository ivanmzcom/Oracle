//
//  ShowDetailView.swift
//  Trakt
//

import SwiftUI

struct ShowDetailView: View {
    @Environment(AuthManager.self) var authManager
    let show: Show

    @State private var posterURL: URL?
    @State private var backdropURL: URL?
    @State private var overview: String?
    @State private var progress: ShowProgress?
    @State private var seasons: [Season] = []
    @State private var isInWatchlist = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var api: TraktAPI {
        TraktAPI(authManager: authManager)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerImage

                VStack(alignment: .leading, spacing: 16) {
                    // Show title and year
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(show.title)
                                .font(.title)
                                .fontWeight(.bold)

                            if let year = show.year {
                                Text(String(year))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        // Watchlist button
                        if authManager.isAuthenticated {
                            Button {
                                Task {
                                    await toggleWatchlist()
                                }
                            } label: {
                                Image(systemName: isInWatchlist ? "bookmark.fill" : "bookmark")
                                    .font(.title2)
                                    .foregroundStyle(isInWatchlist ? .yellow : .primary)
                            }
                            .disabled(isLoading)
                        }
                    }

                    // Progress
                    if let progress = progress, progress.aired > 0 {
                        Divider()
                        progressSection(progress)
                    }

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

                    // Seasons list
                    if !seasons.isEmpty {
                        Divider()
                        seasonsSection
                    }

                    // Watchlist action button
                    if authManager.isAuthenticated {
                        Divider()

                        Button {
                            Task {
                                await toggleWatchlist()
                            }
                        } label: {
                            Label(
                                isInWatchlist ? "Quitar de Watchlist" : "Añadir a Watchlist",
                                systemImage: isInWatchlist ? "bookmark.slash" : "bookmark"
                            )
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isInWatchlist ? Color(.systemGray5) : Color.accentColor)
                            .foregroundStyle(isInWatchlist ? Color.primary : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isLoading)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Spacer(minLength: 32)
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Season.self) { season in
            SeasonDetailView(show: show, season: season)
        }
        .task {
            await loadImages()
            await loadShowDetails()
            await loadSeasons()
            await loadProgress()
            await checkWatchlistStatus()
        }
    }

    // MARK: - Seasons Section

    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Temporadas")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(seasons.filter { $0.number > 0 }) { season in
                    NavigationLink(value: season) {
                        seasonRow(season)
                    }
                    .buttonStyle(.plain)

                    if season.id != seasons.filter({ $0.number > 0 }).last?.id {
                        Divider()
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Specials (Season 0) at the bottom if exists
            if let specials = seasons.first(where: { $0.number == 0 }) {
                NavigationLink(value: specials) {
                    seasonRow(specials)
                }
                .buttonStyle(.plain)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    @ViewBuilder
    private func seasonRow(_ season: Season) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(season.number == 0 ? "Especiales" : "Temporada \(season.number)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let episodeCount = season.episodeCount {
                    Text("\(episodeCount) episodios")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    // MARK: - Progress Section

    @ViewBuilder
    private func progressSection(_ progress: ShowProgress) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progreso")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(progress.completed) de \(progress.aired) episodios")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    let percentage = Int(Double(progress.completed) / Double(progress.aired) * 100)
                    Text("\(percentage)%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.accentColor)
                }

                ProgressView(value: Double(progress.completed), total: Double(progress.aired))
                    .tint(Color.accentColor)

                if let nextEpisode = progress.nextEpisode {
                    nextEpisodeRow(nextEpisode)
                }
            }
        }
    }

    @ViewBuilder
    private func nextEpisodeRow(_ episode: ProgressEpisode) -> some View {
        HStack {
            Text("Siguiente:")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(String(format: "S%02dE%02d", episode.season, episode.number))
                .font(.caption)
                .fontWeight(.medium)

            if let title = episode.title {
                Text("• \(title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
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

    // MARK: - Data Loading

    private func loadImages() async {
        guard let tmdbId = show.ids.tmdb else { return }

        posterURL = await ImageService.shared.getPosterURL(for: tmdbId, size: "w342")
        backdropURL = await ImageService.shared.getBackdropURL(for: tmdbId)
    }

    private func loadShowDetails() async {
        guard let tmdbId = show.ids.tmdb else { return }
        overview = await ImageService.shared.getShowOverview(showId: tmdbId)
    }

    private func loadSeasons() async {
        do {
            seasons = try await api.getShowSeasons(showId: show.id)
        } catch {
            // Silently fail
        }
    }

    private func loadProgress() async {
        guard authManager.isAuthenticated else { return }

        do {
            progress = try await api.getShowProgress(showId: show.id)
        } catch {
            // Silently fail - show might not be in user's history
        }
    }

    private func checkWatchlistStatus() async {
        guard authManager.isAuthenticated else { return }

        do {
            let watchlist = try await api.getWatchlist()
            isInWatchlist = watchlist.contains { $0.show.id == show.id }
        } catch {
            // Silently fail
        }
    }

    private func toggleWatchlist() async {
        isLoading = true
        errorMessage = nil

        do {
            if isInWatchlist {
                try await api.removeFromWatchlist(showId: show.id)
            } else {
                try await api.addToWatchlist(showId: show.id)
            }
            isInWatchlist.toggle()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        ShowDetailView(show: Show(
            title: "The Last of Us",
            year: 2023,
            ids: ShowIds(trakt: 158947, slug: "the-last-of-us", tvdb: nil, imdb: "tt3581920", tmdb: 100088)
        ))
        .environment(AuthManager())
    }
}
