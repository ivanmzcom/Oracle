//
//  WatchSearchView.swift
//  OracleWatch
//

import SwiftUI

struct WatchSearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false

    private let api = WatchTraktAPI()

    var body: some View {
        NavigationStack {
            Group {
                if !api.isAuthenticated {
                    notAuthenticatedView
                } else if searchText.isEmpty && !hasSearched {
                    emptyState
                } else if isSearching {
                    ProgressView()
                } else if searchResults.isEmpty && hasSearched {
                    noResultsView
                } else {
                    resultsList
                }
            }
            .navigationTitle(String(localized: "tab.search"))
            .searchable(text: $searchText, prompt: String(localized: "search.prompt"))
        }
        .onChange(of: searchText) { _, newValue in
            Task {
                await performSearch(query: newValue)
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title)
                .foregroundStyle(.secondary)

            Text(String(localized: "search.empty.title"))
                .font(.headline)
        }
        .padding()
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title)
                .foregroundStyle(.secondary)

            Text(String(localized: "search.noresults.title"))
                .font(.headline)
        }
        .padding()
    }

    // MARK: - Results List

    private var resultsList: some View {
        List(searchResults) { result in
            NavigationLink(value: result.show) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.show.title)
                        .font(.headline)
                        .lineLimit(2)

                    if let year = result.show.year {
                        Text(String(year))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationDestination(for: Show.self) { show in
            WatchShowDetailView(show: show)
        }
    }

    // MARK: - Search

    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            hasSearched = false
            return
        }

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

#Preview {
    WatchSearchView()
}
