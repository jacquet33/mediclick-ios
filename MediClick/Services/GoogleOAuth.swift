import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

/// Inicio de sesión con Google sin SDK: OAuth 2.0 + PKCE con el cliente OAuth de iOS
/// (no lleva secreto) dentro de ASWebAuthenticationSession. Devuelve el id_token,
/// que el servidor verifica contra GOOGLE_CLIENT_ID_IOS.
enum GoogleOAuth {
    enum Cancelado: Error { case cancelado }

    static let clientId = "85175903902-58qlp27n6qr88t5qtmec6begnf5v9e74.apps.googleusercontent.com"
    static var esquema: String { "com.googleusercontent.apps." + clientId.replacingOccurrences(of: ".apps.googleusercontent.com", with: "") }
    static var redirectURI: String { esquema + ":/oauthredirect" }

    @MainActor
    static func idToken() async throws -> String {
        let verifier = aleatorio(64)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
        let state = aleatorio(24)
        var c = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        c.queryItems = [
            .init(name: "client_id", value: clientId),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "prompt", value: "select_account"),
        ]
        let callback: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: c.url!, callbackURLScheme: esquema) { url, error in
                if let url { cont.resume(returning: url); return }
                if let e = error as? ASWebAuthenticationSessionError, e.code == .canceledLogin { cont.resume(throwing: Cancelado.cancelado); return }
                cont.resume(throwing: error ?? Cancelado.cancelado)
            }
            session.presentationContextProvider = Presentador.shared
            session.prefersEphemeralWebBrowserSession = false
            if !session.start() { cont.resume(throwing: Cancelado.cancelado) }
        }
        let q = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard q.first(where: { $0.name == "state" })?.value == state,
              let code = q.first(where: { $0.name == "code" })?.value else {
            throw NSError(domain: "google", code: 2, userInfo: [NSLocalizedDescriptionKey: "Google no devolvió la autorización"])
        }
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let campos = ["client_id": clientId, "code": code, "code_verifier": verifier, "redirect_uri": redirectURI, "grant_type": "authorization_code"]
        req.httpBody = campos.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0.value)" }.joined(separator: "&").data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let token = json["id_token"] as? String else {
            throw NSError(domain: "google", code: 3, userInfo: [NSLocalizedDescriptionKey: "No se pudo completar el ingreso con Google"])
        }
        return token
    }

    private static func aleatorio(_ n: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: n)
        _ = SecRandomCopyBytes(kSecRandomDefault, n, &bytes)
        return Data(bytes).base64URL
    }

    private final class Presentador: NSObject, ASWebAuthenticationPresentationContextProviding {
        static let shared = Presentador()
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}

private extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
