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

    private var api: TraktAPI {
        TraktAPI(authManager: authManager)
    }

    var body: some View {
        NavigationStack {
            Group {
                if !authManager.isAuthenticated {
                    authView
                } else if isLoading && availableGroups.isEmpty && upcomingGroups.isEmpty {
                    ProgressView("Cargando episodios...")
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    episodesList
                }
            }
            .navigationTitle("Próximo")
            .task(id: authManager.isAuthenticated) {
                if authManager.isAuthenticated && availableGroups.isEmpty && upcomingGroups.isEmpty {
                    await loadEpisodes()
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

            Text("Conecta tu cuenta de Trakt")
                .font(.title2)
                .fontWeight(.medium)

            Text("Para ver tus episodios, necesitas iniciar sesión en Trakt.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                authManager.startAuth()
            } label: {
                Label("Iniciar sesión", systemImage: "person.crop.circle")
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
            if !availableGroups.isEmpty {
                Section {
                    ForEach(availableGroups) { group in
                        NavigationLink(value: group) {
                            EpisodeRowView(group: group)
                        }
                    }
                } header: {
                    SectionHeaderView(title: "Up Next", count: availableGroups.map(\.episodeCount).reduce(0, +))
                }
            }

            if !upcomingGroups.isEmpty {
                Section {
                    ForEach(upcomingGroups) { group in
                        NavigationLink(value: group) {
                            EpisodeRowView(group: group)
                        }
                    }
                } header: {
                    SectionHeaderView(title: "Próximamente", count: upcomingGroups.map(\.episodeCount).reduce(0, +))
                }
            }

            if availableGroups.isEmpty && upcomingGroups.isEmpty {
                ContentUnavailableView(
                    "Sin episodios",
                    systemImage: "tv",
                    description: Text("No tienes episodios pendientes")
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
}

#Preview {
    UpcomingView()
        .environment(AuthManager())
}
