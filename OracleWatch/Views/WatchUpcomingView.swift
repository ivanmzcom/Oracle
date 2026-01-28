//
//  WatchUpcomingView.swift
//  OracleWatch
//

import SwiftUI

struct WatchUpcomingView: View {
    @State private var upNextGroups: [EpisodeGroup] = []
    @State private var upcomingGroups: [EpisodeGroup] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = WatchTraktAPI()

    var body: some View {
        NavigationStack {
            Group {
                if !api.isAuthenticated {
                    notAuthenticatedView
                } else if isLoading && upNextGroups.isEmpty && upcomingGroups.isEmpty {
                    ProgressView()
                } else if let error = errorMessage {
                    errorView(error)
                } else if upNextGroups.isEmpty && upcomingGroups.isEmpty {
                    emptyView
                } else {
                    episodesList
                }
            }
            .navigationTitle(String(localized: "tab.upcoming"))
        }
        .task {
            if api.isAuthenticated {
                await loadEpisodes()
            }
        }
    }

    // MARK: - Not Authenticated View

    private var notAuthenticatedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Open Oracle on iPhone to log in")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tv")
                .font(.title)
                .foregroundStyle(.secondary)

            Text(String(localized: "upcoming.empty.title"))
                .font(.headline)

            Text(String(localized: "upcoming.empty.description"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.orange)

            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)

            Button(String(localized: "upcoming.retry")) {
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
            if !upNextGroups.isEmpty {
                Section("Up Next") {
                    ForEach(upNextGroups) { group in
                        NavigationLink(value: group) {
                            WatchEpisodeRow(group: group)
                        }
                    }
                }
            }

            if !upcomingGroups.isEmpty {
                Section(String(localized: "intent.shortcut.upcoming")) {
                    ForEach(upcomingGroups) { group in
                        NavigationLink(value: group) {
                            WatchEpisodeRow(group: group)
                        }
                    }
                }
            }
        }
        .navigationDestination(for: EpisodeGroup.self) { group in
            WatchEpisodeDetailView(group: group)
        }
    }

    // MARK: - Data Loading

    private func loadEpisodes() async {
        isLoading = true
        errorMessage = nil

        do {
            async let upNext = api.getUpNextEpisodes()
            async let upcoming = api.getUpcomingEpisodes()

            let (upNextResult, upcomingResult) = try await (upNext, upcoming)

            upNextGroups = upNextResult.groupedByShowAndSeason()
            upcomingGroups = upcomingResult.asIndividualGroups()
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
}

#Preview {
    WatchUpcomingView()
}
