//
//  AuthManager.swift
//  Trakt
//

import Foundation
import Security
import Observation

@Observable
@MainActor
class AuthManager {
    var isAuthenticated = false
    var isAuthenticating = false
    var deviceCode: DeviceCodeResponse?
    var errorMessage: String?

    private var pollTimer: Timer?
    private static let sharedDefaults = UserDefaults(suiteName: "group.com.ivanmz.Trakt")

    init() {
        checkAuthStatus()
    }

    func checkAuthStatus() {
        isAuthenticated = getAccessToken() != nil
    }

    // MARK: - Device Code Flow

    func startDeviceAuth() async {
        isAuthenticating = true
        errorMessage = nil

        let url = URL(string: "\(TraktConfig.baseURL)\(TraktConfig.Endpoints.deviceCode)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["client_id": TraktConfig.clientId]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
            deviceCode = response
            startPolling(deviceCode: response.deviceCode, interval: response.interval)
        } catch {
            errorMessage = "Error al iniciar autenticación: \(error.localizedDescription)"
            isAuthenticating = false
        }
    }

    private func startPolling(deviceCode: String, interval: Int) {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pollForToken(deviceCode: deviceCode)
            }
        }
    }

    private func pollForToken(deviceCode: String) async {
        let url = URL(string: "\(TraktConfig.baseURL)\(TraktConfig.Endpoints.deviceToken)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "code": deviceCode,
            "client_id": TraktConfig.clientId,
            "client_secret": TraktConfig.clientSecret
        ]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else { return }

            switch httpResponse.statusCode {
            case 200:
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                saveTokens(tokenResponse)
                pollTimer?.invalidate()
                isAuthenticated = true
                isAuthenticating = false
                self.deviceCode = nil

            case 400:
                // Pending - user hasn't authorized yet, continue polling
                break

            case 404:
                // Invalid device code
                pollTimer?.invalidate()
                errorMessage = "Código de dispositivo inválido"
                isAuthenticating = false

            case 409:
                // Code already used
                pollTimer?.invalidate()
                errorMessage = "Código ya utilizado"
                isAuthenticating = false

            case 410:
                // Code expired
                pollTimer?.invalidate()
                errorMessage = "Código expirado"
                isAuthenticating = false

            case 418:
                // User denied
                pollTimer?.invalidate()
                errorMessage = "Acceso denegado"
                isAuthenticating = false

            case 429:
                // Polling too fast
                break

            default:
                break
            }
        } catch {
            // Network error, continue polling
        }
    }

    func cancelAuth() {
        pollTimer?.invalidate()
        isAuthenticating = false
        deviceCode = nil
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

// MARK: - Response Models

struct DeviceCodeResponse: Codable, Sendable {
    let deviceCode: String
    let userCode: String
    let verificationUrl: String
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUrl = "verification_url"
        case expiresIn = "expires_in"
        case interval
    }
}

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
