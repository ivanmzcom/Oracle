//
//  ContentView.swift
//  Trakt
//
//  Created by Iván Moreno Zambudio on 27/1/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            UpcomingView()
                .tabItem {
                    Label("Próximo", systemImage: "play.circle")
                }

            HistoryView()
                .tabItem {
                    Label("Historial", systemImage: "clock.arrow.circlepath")
                }

            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthManager())
}
