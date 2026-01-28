//
//  TraktApp.swift
//  Trakt
//
//  Created by Iván Moreno Zambudio on 27/1/26.
//

import SwiftUI

@main
struct TraktApp: App {
    @State private var authManager = AuthManager()

    init() {
        // Store API keys in shared UserDefaults so the widget can access them
        let sharedDefaults = UserDefaults(suiteName: "group.com.ivanmz.Trakt")
        sharedDefaults?.set(TraktConfig.clientId, forKey: "trakt_client_id")
        sharedDefaults?.set(TMDBConfig.apiKey, forKey: "tmdb_api_key")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
        }
    }
}
