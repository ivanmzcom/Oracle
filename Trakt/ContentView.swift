//
//  ContentView.swift
//  Trakt
//
//  Created by Iván Moreno Zambudio on 27/1/26.
//

import SwiftUI

struct ContentView: View {
    @State private var searchText = ""

    var body: some View {
        TabView {
            Tab(String(localized: "tab.upcoming"), systemImage: "play.circle") {
                UpcomingView()
            }

            Tab(String(localized: "tab.history"), systemImage: "clock.arrow.circlepath") {
                HistoryView()
            }

            Tab(role: .search) {
                NavigationStack {
                    SearchView(searchText: $searchText)
                        .navigationTitle(String(localized: "tab.search"))
                }
                .searchable(text: $searchText, prompt: String(localized: "search.prompt"))
            }

            Tab(String(localized: "tab.settings"), systemImage: "gear") {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthManager())
}
