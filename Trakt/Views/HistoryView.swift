//
//  HistoryView.swift
//  Trakt
//

import SwiftUI

struct HistoryView: View {
    @Environment(AuthManager.self) var authManager

    @State private var historyEntries: [HistoryEntry] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var deleteError: String?
    @State private var currentPage = 1
    @State private var hasMorePages = true

    private let pageSize = 50

    private var api: TraktAPI {
        TraktAPI(authManager: authManager)
    }

    private var historyGroups: [EpisodeGroup] {
        historyEntries.asHistoryGroups()
    }

    var body: some View {
        NavigationStack {
            Group {
                if !authManager.isAuthenticated {
                    authView
                } else if isLoading && historyGroups.isEmpty {
                    ProgressView(String(localized: "history.loading"))
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    historyList
                }
            }
            .navigationTitle(String(localized: "history.title"))
            .task(id: authManager.isAuthenticated) {
                if authManager.isAuthenticated && historyGroups.isEmpty {
                    await loadHistory()
                }
            }
            .alert(String(localized: "history.delete.error"), isPresented: .init(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = deleteError {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Auth View

    private var authView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(String(localized: "auth.connect"))
                .font(.title2)
                .fontWeight(.medium)

            Text(String(localized: "auth.connect.history"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                authManager.startAuth()
            } label: {
                Label(String(localized: "auth.login"), systemImage: "person.crop.circle")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
            .disabled(authManager.isAuthenticating)

            if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text(String(localized: "history.error"))
                .font(.title2)
                .fontWeight(.medium)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
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
            ForEach(historyGroupedByDay, id: \.date) { dayGroup in
                Section {
                    ForEach(dayGroup.episodes) { group in
                        NavigationLink(value: group) {
                            EpisodeRowView(group: group)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await deleteHistoryEntry(for: group)
                                }
                            } label: {
                                Label(String(localized: "history.delete"), systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    SectionHeaderView(title: formatDayHeader(dayGroup.date), count: dayGroup.episodes.map(\.episodeCount).reduce(0, +))
                }
            }

            // Pagination trigger
            if hasMorePages && !historyGroups.isEmpty {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        Task {
                            await loadMoreHistory()
                        }
                    }
            }

            if isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            if historyGroups.isEmpty && !isLoading {
                ContentUnavailableView(
                    String(localized: "history.empty.title"),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(String(localized: "history.empty.description"))
                )
            }
        }
        .navigationDestination(for: EpisodeGroup.self) { group in
            EpisodeDetailView(group: group)
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await refreshHistory()
        }
    }

    // MARK: - Grouped by Day

    private struct DayGroup {
        let date: Date
        let episodes: [EpisodeGroup]
    }

    private var historyGroupedByDay: [DayGroup] {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: historyGroups) { group in
            calendar.startOfDay(for: group.firstAired)
        }

        return grouped
            .map { DayGroup(date: $0.key, episodes: $0.value.sorted { $0.firstAired > $1.firstAired }) }
            .sorted { $0.date > $1.date }
    }

    private func formatDayHeader(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return String(localized: "date.today")
        } else if calendar.isDateInYesterday(date) {
            return String(localized: "date.yesterday")
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: calendar.startOfDay(for: Date())).day,
                  daysAgo < 7 {
            // Show day name for this week
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date).capitalized
        } else {
            // Show full date
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            return formatter.string(from: date)
        }
    }

    // MARK: - Data Loading

    private func loadHistory() async {
        isLoading = true
        errorMessage = nil
        currentPage = 1
        hasMorePages = true

        do {
            let entries = try await api.getWatchHistory(page: 1, limit: pageSize)
            historyEntries = entries
            hasMorePages = entries.count >= pageSize
        } catch is CancellationError {
            // Task was cancelled, ignore
        } catch let urlError as URLError where urlError.code == .cancelled {
            // URLSession request was cancelled, ignore
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func refreshHistory() async {
        currentPage = 1
        hasMorePages = true

        do {
            let entries = try await api.getWatchHistory(page: 1, limit: pageSize)
            historyEntries = entries
            hasMorePages = entries.count >= pageSize
        } catch is CancellationError {
            // Task was cancelled, ignore
        } catch let urlError as URLError where urlError.code == .cancelled {
            // URLSession request was cancelled, ignore
        } catch {
            // Don't show error on refresh, just keep old data
        }
    }

    private func loadMoreHistory() async {
        guard !isLoadingMore && hasMorePages else { return }

        isLoadingMore = true
        let nextPage = currentPage + 1

        do {
            let entries = try await api.getWatchHistory(page: nextPage, limit: pageSize)
            if entries.isEmpty {
                hasMorePages = false
            } else {
                historyEntries.append(contentsOf: entries)
                currentPage = nextPage
                hasMorePages = entries.count >= pageSize
            }
        } catch {
            // Silently fail on load more, user can scroll up and down to retry
        }

        isLoadingMore = false
    }

    private func deleteHistoryEntry(for group: EpisodeGroup) async {
        // Find the history entry that matches this group
        guard let entry = historyEntries.first(where: {
            $0.show.id == group.show.id &&
            $0.episode.season == group.season &&
            $0.episode.number == group.episodes.first?.episode.number
        }) else {
            return
        }

        do {
            try await api.removeFromHistory(historyId: entry.id)
            // Remove from local state with animation
            withAnimation {
                historyEntries.removeAll { $0.id == entry.id }
            }
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

#Preview {
    HistoryView()
        .environment(AuthManager())
}
