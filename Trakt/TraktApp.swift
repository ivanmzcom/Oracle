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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
        }
    }
}
