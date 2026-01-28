//
//  SettingsView.swift
//  Trakt
//

import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) var authManager

    @State private var user: TraktUser?
    @State private var isLoading = false
    @State private var showingLogoutAlert = false

    private var api: TraktAPI {
        TraktAPI(authManager: authManager)
    }

    var body: some View {
        NavigationStack {
            List {
                if authManager.isAuthenticated {
                    if let user = user {
                        accountSection(user: user)
                    } else if isLoading {
                        Section {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }
                    }

                    logoutSection
                } else {
                    notAuthenticatedSection
                }

                aboutSection
            }
            .navigationTitle(String(localized: "settings.title"))
            .task {
                if authManager.isAuthenticated && user == nil {
                    await loadUser()
                }
            }
            .refreshable {
                await loadUser()
            }
            .alert(String(localized: "settings.logout.title"), isPresented: $showingLogoutAlert) {
                Button(String(localized: "settings.logout.cancel"), role: .cancel) { }
                Button(String(localized: "settings.logout"), role: .destructive) {
                    authManager.logout()
                    user = nil
                }
            } message: {
                Text(String(localized: "settings.logout.message"))
            }
        }
    }

    // MARK: - Account Section

    private func accountSection(user: TraktUser) -> some View {
        Section {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: user.images?.avatar?.full ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(.secondary)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name ?? user.username)
                        .font(.headline)

                    if user.name != nil {
                        Text("@\(user.username)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if user.vip == true {
                        Label("VIP", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)

            if let joinedAt = user.joinedAt {
                LabeledContent(String(localized: "settings.member.since"), value: formattedDate(joinedAt))
            }

            if let location = user.location, !location.isEmpty {
                LabeledContent(String(localized: "settings.location"), value: location)
            }
        } header: {
            Text(String(localized: "settings.account"))
        }
    }

    // MARK: - Logout Section

    private var logoutSection: some View {
        Section {
            Button(role: .destructive) {
                showingLogoutAlert = true
            } label: {
                HStack {
                    Spacer()
                    Text(String(localized: "settings.logout"))
                    Spacer()
                }
            }
        }
    }

    // MARK: - Not Authenticated Section

    private var notAuthenticatedSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                Text(String(localized: "settings.notloggedin.title"))
                    .font(.headline)

                Text(String(localized: "settings.notloggedin.description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            LabeledContent(String(localized: "settings.version"), value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")

            Link(destination: URL(string: "https://trakt.tv")!) {
                HStack {
                    Text("Trakt.tv")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(String(localized: "settings.about"))
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func loadUser() async {
        isLoading = true
        do {
            user = try await api.getUserSettings()
        } catch {
            // Ignore errors
        }
        isLoading = false
    }
}

#Preview {
    SettingsView()
        .environment(AuthManager())
}
