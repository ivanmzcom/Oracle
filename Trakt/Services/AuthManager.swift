//
//  AuthManager.swift
//  Trakt
//

import AuthenticationServices
import Foundation
import Observation
import Security

@Observable
@MainActor
class AuthManager: NSObject {
    var isAuthenticated = false
    var isAuthenticating = false
    var errorMessage: String?

    private var webAuthSession: ASWebAuthenticationSession?
    private static let sharedDefaults = UserDefaults(suiteName: "group.com.ivanmz.Trakt")

    override init() {
        super.init()
        checkAuthStatus()
    }

    func checkAuthStatus() {
        isAuthenticated = getAccessToken() != nil
    }

    // MARK: - OAuth Flow with ASWebAuthenticationSession

    func startAuth() {
        isAuthenticating = true
        errorMessage = nil

        var components = URLComponents(string: "\(TraktConfig.baseURL)\(TraktConfig.Endpoints.authorize)")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: TraktConfig.clientId),
            URLQueryItem(name: "redirect_uri", value: TraktConfig.redirectURI)
        ]

        guard let authURL = components.url else {
            errorMessage = "Error al crear URL de autenticación"
            isAuthenticating = false
            return
        }

        webAuthSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "oracleimz"
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                await self?.handleCallback(url: callbackURL, error: error)
            }
        }

        webAuthSession?.presentationContextProvider = self
        webAuthSession?.prefersEphemeralWebBrowserSession = false
        webAuthSession?.start()
    }

    private func handleCallback(url: URL?, error: Error?) async {
        defer { isAuthenticating = false }

        if let error = error as? ASWebAuthenticationSessionError {
            if error.code == .canceledLogin {
                // User cancelled, no error message needed
                return
            }
            errorMessage = "Error de autenticación: \(error.localizedDescription)"
            return
        }

        guard let url = url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            errorMessage = "No se recibió código de autorización"
            return
        }

        await exchangeCodeForToken(code: code)
    }

    private func exchangeCodeForToken(code: String) async {
        guard let url = URL(string: "\(TraktConfig.baseURL)\(TraktConfig.Endpoints.token)") else {
            errorMessage = "URL inválida"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "code": code,
            "client_id": TraktConfig.clientId,
            "client_secret": TraktConfig.clientSecret,
            "redirect_uri": TraktConfig.redirectURI,
            "grant_type": "authorization_code"
        ]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Respuesta inválida del servidor"
                return
            }

            if httpResponse.statusCode == 200 {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                saveTokens(tokenResponse)
                isAuthenticated = true
            } else {
                errorMessage = "Error al obtener token: \(httpResponse.statusCode)"
            }
        } catch {
            errorMessage = "Error de red: \(error.localizedDescription)"
        }
    }

    func cancelAuth() {
        webAuthSession?.cancel()
        isAuthenticating = false
    }

    func logout() {
        deleteToken(key: TraktConfig.Keychain.accessToken)
        deleteToken(key: TraktConfig.Keychain.refreshToken)
        deleteToken(key: TraktConfig.Keychain.expiresAt)
        Self.sharedDefaults?.removeObject(forKey: TraktConfig.Keychain.accessToken)
        isAuthenticated = false
    }

    // MARK: - Token Management

    private func saveTokens(_ response: TokenResponse) {
        saveToken(response.accessToken, key: TraktConfig.Keychain.accessToken)
        saveToken(response.refreshToken, key: TraktConfig.Keychain.refreshToken)

        let expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        saveToken(String(expiresAt.timeIntervalSince1970), key: TraktConfig.Keychain.expiresAt)

        // Mirror access token to shared app group so the widget can read it
        Self.sharedDefaults?.set(response.accessToken, forKey: TraktConfig.Keychain.accessToken)
    }

    nonisolated func getAccessToken() -> String? {
        getToken(key: TraktConfig.Keychain.accessToken)
            ?? Self.sharedDefaults?.string(forKey: TraktConfig.Keychain.accessToken)
    }

    /// Returns a valid access token, refreshing if needed
    func getValidAccessToken() async -> String? {
        // Check if token is expired
        if let expiresAtString = getToken(key: TraktConfig.Keychain.expiresAt),
           let expiresAt = Double(expiresAtString) {
            let expirationDate = Date(timeIntervalSince1970: expiresAt)
            // Refresh if expires in less than 5 minutes
            if expirationDate < Date().addingTimeInterval(300) {
                await refreshToken()
            }
        }

        return getAccessToken()
    }

    private func refreshToken() async {
        guard let refreshToken = getToken(key: TraktConfig.Keychain.refreshToken) else {
            logout()
            return
        }

        guard let url = URL(string: "\(TraktConfig.baseURL)\(TraktConfig.Endpoints.token)") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "refresh_token": refreshToken,
            "client_id": TraktConfig.clientId,
            "client_secret": TraktConfig.clientSecret,
            "redirect_uri": TraktConfig.redirectURI,
            "grant_type": "refresh_token"
        ]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logout()
                return
            }

            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            saveTokens(tokenResponse)
        } catch {
            logout()
        }
    }

    // MARK: - Keychain Helpers

    private nonisolated func saveToken(_ token: String, key: String) {
        let data = token.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private nonisolated func getToken(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    private nonisolated func deleteToken(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}

// MARK: - Response Models

struct TokenResponse: Codable, Sendable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    let scope: String
    let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case createdAt = "created_at"
    }
}
