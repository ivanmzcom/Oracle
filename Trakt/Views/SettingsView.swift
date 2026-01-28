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
            .navigationTitle("Ajustes")
            .task {
                if authManager.isAuthenticated && user == nil {
                    await loadUser()
                }
            }
            .refreshable {
                await loadUser()
            }
            .alert("Cerrar sesión", isPresented: $showingLogoutAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Cerrar sesión", role: .destructive) {
                    authManager.logout()
                    user = nil
                }
            } message: {
                Text("¿Estás seguro de que quieres cerrar sesión?")
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
                LabeledContent("Miembro desde", value: formattedDate(joinedAt))
            }

            if let location = user.location, !location.isEmpty {
                LabeledContent("Ubicación", value: location)
            }
        } header: {
            Text("Cuenta")
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
                    Text("Cerrar sesión")
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

                Text("No has iniciado sesión")
                    .font(.headline)

                Text("Inicia sesión en la pestaña Próximo para ver tu cuenta.")
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
            LabeledContent("Versión", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")

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
            Text("Acerca de")
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "es_ES")
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
