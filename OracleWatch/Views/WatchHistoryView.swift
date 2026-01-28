//
//  WatchHistoryView.swift
//  OracleWatch
//

import SwiftUI

struct WatchHistoryView: View {
    @State private var historyGroups: [EpisodeGroup] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = WatchTraktAPI()

    var body: some View {
        NavigationStack {
            Group {
                if !api.isAuthenticated {
                    notAuthenticatedView
                } else if isLoading && historyGroups.isEmpty {
                    ProgressView()
                } else if let error = errorMessage {
                    errorView(error)
                } else if historyGroups.isEmpty {
                    emptyView
                } else {
                    historyList
                }
            }
            .navigationTitle(String(localized: "tab.history"))
        }
        .task {
            if api.isAuthenticated {
                await loadHistory()
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
            Image(systemName: "clock.arrow.circlepath")
                .font(.title)
                .foregroundStyle(.secondary)

            Text(String(localized: "history.empty.title"))
                .font(.headline)

            Text(String(localized: "history.empty.description"))
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

            Button(String(localized: "history.retry")) {
                Task {
                    await loadHistory()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - History List

    private var historyList: some View {
        List {
            ForEach(historyGroups) { group in
                NavigationLink(value: group) {
                    WatchEpisodeRow(group: group, showDate: true)
                }
            }
        }
        .navigationDestination(for: EpisodeGroup.self) { group in
            WatchEpisodeDetailView(group: group)
        }
    }

    // MARK: - Data Loading

    private func loadHistory() async {
        isLoading = true
        errorMessage = nil

        do {
            let entries = try await api.getWatchHistory(limit: 30)
            historyGroups = entries.asHistoryGroups()
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
}

#Preview {
    WatchHistoryView()
}
