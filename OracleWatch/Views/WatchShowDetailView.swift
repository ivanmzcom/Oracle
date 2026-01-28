//
//  WatchShowDetailView.swift
//  OracleWatch
//

import SwiftUI

struct WatchShowDetailView: View {
    let show: Show

    @State private var progress: ShowProgress?
    @State private var isLoading = false

    private let api = WatchTraktAPI()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Show title
                Text(show.title)
                    .font(.headline)

                if let year = show.year {
                    Text(String(year))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Progress
                if let progress = progress {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "show.progress"))
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack {
                            Text("\(progress.completed)/\(progress.aired)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            let percentage = progress.aired > 0 ? Int(Double(progress.completed) / Double(progress.aired) * 100) : 0
                            Text("\(percentage)%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.accentColor)
                        }

                        ProgressView(value: Double(progress.completed), total: Double(max(progress.aired, 1)))
                            .tint(.accentColor)

                        // Next episode
                        if let nextEpisode = progress.nextEpisode {
                            HStack {
                                Text(String(localized: "show.progress.next"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Text(String(format: "S%02dE%02d", nextEpisode.season, nextEpisode.number))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }

                            if let title = nextEpisode.title {
                                Text(title)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                }
            }
            .padding()
        }
        .navigationTitle(show.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProgress()
        }
    }

    private func loadProgress() async {
        guard api.isAuthenticated else { return }

        isLoading = true

        do {
            progress = try await api.getShowProgress(showId: show.id)
        } catch {
            // Silently fail
        }

        isLoading = false
    }
}

#Preview {
    let show = Show(
        title: "The Last of Us",
        year: 2023,
        ids: ShowIds(trakt: 1, slug: "the-last-of-us", tvdb: nil, imdb: nil, tmdb: 100088)
    )

    return NavigationStack {
        WatchShowDetailView(show: show)
    }
}
