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
            Tab("Próximo", systemImage: "play.circle") {
                UpcomingView()
            }

            Tab("Historial", systemImage: "clock.arrow.circlepath") {
                HistoryView()
            }

            Tab(role: .search) {
                NavigationStack {
                    SearchView(searchText: $searchText)
                        .navigationTitle("Buscar")
                }
                .searchable(text: $searchText, prompt: "Buscar series...")
            }

            Tab("Ajustes", systemImage: "gear") {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthManager())
}
