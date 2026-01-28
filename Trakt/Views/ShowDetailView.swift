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
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                    Text(String(year))
                                        .font(.subheadline)
                                }
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
                        progressSection(progress)
                        Divider()
                    }

                    // Overview
                    if let overview = overview, !overview.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "show.synopsis"))
                                .font(.headline)

                            Text(overview)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                    }

                    // Seasons list
                    if !seasons.isEmpty {
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
                                isInWatchlist ? String(localized: "show.watchlist.remove") : String(localized: "show.watchlist.add"),
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
            Text(String(localized: "show.seasons"))
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
                Text(season.number == 0 ? String(localized: "show.specials") : String(localized: "show.season", defaultValue: "Season \(season.number)"))
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let episodeCount = season.episodeCount {
                    Text(String(localized: "show.episodes.count", defaultValue: "\(episodeCount) episodes"))
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
            Text(String(localized: "show.progress"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                // Progress bar with percentage
                HStack(alignment: .center, spacing: 12) {
                    let percentage = Int(Double(progress.completed) / Double(progress.aired) * 100)

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))

                            // Filled portion with gradient
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(progress.completed) / CGFloat(progress.aired))
                        }
                    }
                    .frame(height: 8)

                    // Percentage with color based on completion
                    Text("\(percentage)%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(percentageColor(percentage))
                        .frame(minWidth: 44, alignment: .trailing)
                }

                // Episode count
                Text(String(localized: "show.progress.episodes", defaultValue: "\(progress.completed) of \(progress.aired) episodes"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Next episode card
                if let nextEpisode = progress.nextEpisode {
                    nextEpisodeCard(nextEpisode)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func percentageColor(_ percentage: Int) -> Color {
        if percentage >= 100 {
            return .green
        } else if percentage >= 50 {
            return .accentColor
        } else {
            return .secondary
        }
    }

    @ViewBuilder
    private func nextEpisodeCard(_ episode: ProgressEpisode) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "show.progress.next"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    // Episode code pill
                    Text(String(format: "S%02dE%02d", episode.season, episode.number))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())

                    if let title = episode.title {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
