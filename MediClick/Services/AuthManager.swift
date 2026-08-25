import Foundation
import Observation

@Observable
final class AuthManager {
    var isAuthenticated: Bool = false
    var currentDoctor: LocalDoctor?
    var organizations: [OrgInfo] = []
    var activeOrganization: OrgInfo?
    var isLoading: Bool = false
    var errorMessage: String?
    
    struct OrgInfo: Identifiable, Codable {
        let id: String
        let orgDoctorId: String
        let name: String
        let type: String
        let role: String
    }
    
    init() {
        // Check stored tokens
        if let _ = KeychainHelper.load(key: "access_token") {
            isAuthenticated = true
        }
    }
    
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let body: [String: String] = ["email": email, "password": password]
            let data = try JSONSerialization.data(withJSONObject: body)
            
            var request = URLRequest(url: URL(string: "\(APIConfig.baseURL)/api/v1/auth/login")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw AuthError.invalidCredentials
            }
            
            let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            
            if let accessToken = json?["accessToken"] as? String,
               let refreshToken = json?["refreshToken"] as? String {
                KeychainHelper.save(key: "access_token", value: accessToken)
                KeychainHelper.save(key: "refresh_token", value: refreshToken)
            }
            
            await MainActor.run {
                isAuthenticated = true
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Email o contraseña incorrectos"
                isLoading = false
            }
        }
    }
    
    func logout() {
        KeychainHelper.delete(key: "access_token")
        KeychainHelper.delete(key: "refresh_token")
        isAuthenticated = false
        currentDoctor = nil
        organizations = []
        activeOrganization = nil
    }
    
    func selectOrganization(_ org: OrgInfo) {
        activeOrganization = org
        UserDefaults.standard.set(org.id, forKey: "active_org_id")
    }
}

enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Email o contraseña incorrectos"
        case .networkError: return "Error de conexión"
        }
    }
}

enum APIConfig {
    // Cambiar por la URL del servidor en producción
    static var baseURL: String {
        #if DEBUG
        return "http://localhost:3000"
        #else
        return "https://api.mediclick.com"
        #endif
    }
}
