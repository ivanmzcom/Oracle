//
//  ContentView.swift
//  OracleWatch
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            WatchUpcomingView()
                .tabItem {
                    Label(String(localized: "tab.upcoming"), systemImage: "play.circle")
                }

            WatchHistoryView()
                .tabItem {
                    Label(String(localized: "tab.history"), systemImage: "clock.arrow.circlepath")
                }

            WatchSearchView()
                .tabItem {
                    Label(String(localized: "tab.search"), systemImage: "magnifyingglass")
                }
        }
    }
}

#Preview {
    ContentView()
}
