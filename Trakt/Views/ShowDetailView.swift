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
        .task {
            await loadImages()
            await loadShowDetails()
            await checkWatchlistStatus()
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
