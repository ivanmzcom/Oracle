//
//  UpcomingView.swift
//  Trakt
//

import SwiftUI
import WidgetKit

struct UpcomingView: View {
    @Environment(AuthManager.self) var authManager

    @State private var availableGroups: [EpisodeGroup] = []
    @State private var upcomingGroups: [EpisodeGroup] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var dropError: String?
    @State private var lastLoadTime: Date?

    private var api: TraktAPI {
        TraktAPI(authManager: authManager)
    }

    var body: some View {
        NavigationStack {
            Group {
                if !authManager.isAuthenticated {
                    authView
                } else if isLoading && availableGroups.isEmpty && upcomingGroups.isEmpty {
                    ProgressView(String(localized: "upcoming.loading"))
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    episodesList
                }
            }
            .navigationTitle(String(localized: "upcoming.title"))
            .task(id: authManager.isAuthenticated) {
                if authManager.isAuthenticated && availableGroups.isEmpty && upcomingGroups.isEmpty {
                    await loadEpisodes()
                }
            }
            .onAppear {
                // Refresh if data is older than 2 minutes
                if let lastLoad = lastLoadTime,
                   Date().timeIntervalSince(lastLoad) > 120,
                   authManager.isAuthenticated {
                    Task {
                        await loadEpisodes()
                    }
                }
            }
            .alert(String(localized: "upcoming.drop.error"), isPresented: .init(
                get: { dropError != nil },
                set: { if !$0 { dropError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = dropError {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Auth View

    private var authView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tv")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(String(localized: "auth.connect"))
                .font(.title2)
                .fontWeight(.medium)

            Text(String(localized: "auth.connect.upcoming"))
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

            Text(String(localized: "upcoming.error"))
                .font(.title2)
                .fontWeight(.medium)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
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
            if !availableGroups.isEmpty {
                Section {
                    ForEach(availableGroups) { group in
                        NavigationLink(value: group) {
                            EpisodeRowView(group: group)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await dropShow(group.show)
                                }
                            } label: {
                                Label(String(localized: "upcoming.drop"), systemImage: "eye.slash")
                            }
                        }
                    }
                } header: {
                    SectionHeaderView(title: "Up Next", count: availableGroups.map(\.episodeCount).reduce(0, +))
                }
            }

            ForEach(upcomingGroupedByDay, id: \.date) { dayGroup in
                Section {
                    ForEach(dayGroup.episodes) { group in
                        NavigationLink(value: group) {
                            EpisodeRowView(group: group)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await dropShow(group.show)
                                }
                            } label: {
                                Label(String(localized: "upcoming.drop"), systemImage: "eye.slash")
                            }
                        }
                    }
                } header: {
                    SectionHeaderView(title: formatDayHeader(dayGroup.date), count: dayGroup.episodes.map(\.episodeCount).reduce(0, +))
                }
            }

            if availableGroups.isEmpty && upcomingGroups.isEmpty {
                ContentUnavailableView(
                    String(localized: "upcoming.empty.title"),
                    systemImage: "tv",
                    description: Text(String(localized: "upcoming.empty.description"))
                )
            }
        }
        .navigationDestination(for: EpisodeGroup.self) { group in
            EpisodeDetailView(group: group)
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadEpisodes()
        }
    }

    // MARK: - Grouped by Day

    private struct DayGroup {
        let date: Date
        let episodes: [EpisodeGroup]
    }

    private var upcomingGroupedByDay: [DayGroup] {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: upcomingGroups) { group in
            calendar.startOfDay(for: group.firstAired)
        }

        return grouped
            .map { DayGroup(date: $0.key, episodes: $0.value.sorted { $0.firstAired < $1.firstAired }) }
            .sorted { $0.date < $1.date }
    }

    private func formatDayHeader(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return String(localized: "date.today")
        } else if calendar.isDateInTomorrow(date) {
            return String(localized: "date.tomorrow")
        } else if let daysUntil = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: date).day,
                  daysUntil < 7 {
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

    private func loadEpisodes() async {
        isLoading = true
        errorMessage = nil

        do {
            async let upNext = api.getUpNextEpisodes()
            async let upcoming = api.getUpcomingEpisodes()

            let (upNextResult, upcomingResult) = try await (upNext, upcoming)

            availableGroups = upNextResult.groupedByShowAndSeason()
            upcomingGroups = upcomingResult.asIndividualGroups()
            lastLoadTime = Date()

            // Save upcoming episodes to shared storage for the widget
            let entries = Array(upcomingResult.prefix(10))
            let widgetEpisodes = await withTaskGroup(of: (Int, WidgetEpisodeData).self) { group in
                for (index, entry) in entries.enumerated() {
                    group.addTask {
                        let posterURL = await ImageService.shared.getPosterURL(for: entry.show.ids.tmdb)
                        return (index, WidgetEpisodeData(
                            showTitle: entry.show.title,
                            episodeCode: entry.episode.episodeCode,
                            posterURL: posterURL?.absoluteString
                        ))
                    }
                }
                var results: [(Int, WidgetEpisodeData)] = []
                for await result in group {
                    results.append(result)
                }
                return results.sorted { $0.0 < $1.0 }.map(\.1)
            }
            if let data = try? JSONEncoder().encode(widgetEpisodes) {
                UserDefaults(suiteName: "group.com.ivanmz.Trakt")?.set(data, forKey: "widget_episodes")
            }
            WidgetCenter.shared.reloadAllTimelines()
        } catch is CancellationError {
            // Task was cancelled, ignore
        } catch let urlError as URLError where urlError.code == .cancelled {
            // URLSession request was cancelled, ignore
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func dropShow(_ show: Show) async {
        do {
            try await api.dropShow(showId: show.id)
            // Remove from local state with animation
            withAnimation {
                availableGroups.removeAll { $0.show.id == show.id }
                upcomingGroups.removeAll { $0.show.id == show.id }
            }
        } catch {
            dropError = error.localizedDescription
        }
    }
}

#Preview {
    UpcomingView()
        .environment(AuthManager())
}
