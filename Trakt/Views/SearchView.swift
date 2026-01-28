//
//  SearchView.swift
//  Trakt
//

import SwiftUI

struct SearchView: View {
    @Environment(AuthManager.self) var authManager
    @Binding var searchText: String

    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false

    private var api: TraktAPI {
        TraktAPI(authManager: authManager)
    }

    var body: some View {
        Group {
            if searchText.isEmpty && !hasSearched {
                emptyState
            } else if isSearching {
                ProgressView(String(localized: "search.loading"))
            } else if searchResults.isEmpty && hasSearched {
                noResultsView
            } else {
                resultsList
            }
        }
        .onChange(of: searchText) { _, newValue in
            Task {
                await performSearch(query: newValue)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            String(localized: "search.empty.title"),
            systemImage: "magnifyingglass",
            description: Text(String(localized: "search.empty.description"))
        )
    }

    // MARK: - No Results

    private var noResultsView: some View {
        ContentUnavailableView(
            String(localized: "search.noresults.title"),
            systemImage: "magnifyingglass",
            description: Text(String(localized: "search.noresults.description", defaultValue: "No shows found for \"\(searchText)\""))
        )
    }

    // MARK: - Results List

    private var resultsList: some View {
        List(searchResults) { result in
            NavigationLink(value: result.show) {
                SearchResultRow(show: result.show)
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Show.self) { show in
            ShowDetailView(show: show)
        }
    }

    // MARK: - Search

    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            hasSearched = false
            return
        }

        // Debounce
        try? await Task.sleep(for: .milliseconds(300))

        guard !Task.isCancelled else { return }

        isSearching = true

        do {
            searchResults = try await api.searchShows(query: query)
            hasSearched = true
        } catch {
            searchResults = []
        }

        isSearching = false
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let show: Show

    @State private var posterURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: posterURL) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .overlay {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                case .failure:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "tv")
                                .foregroundStyle(.secondary)
                        }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 50, height: 75)

            VStack(alignment: .leading, spacing: 4) {
                Text(show.title)
                    .font(.headline)

                if let year = show.year {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .task {
            posterURL = await ImageService.shared.getPosterURL(for: show.ids.tmdb)
        }
    }
}

#Preview {
    NavigationStack {
        SearchView(searchText: .constant(""))
            .environment(AuthManager())
    }
}
