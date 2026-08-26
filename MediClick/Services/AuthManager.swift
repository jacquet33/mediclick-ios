import Foundation
import Observation

@Observable
final class AuthManager {
    var isAuthenticated: Bool = false
    var organizations: [OrgInfo] = []
    var activeOrganization: OrgInfo?
    var isLoading: Bool = false
    var errorMessage: String?
    
    // Doctor data
    var doctorId: String = ""
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var specialty: String = "Clínica médica"
    var medicalLicense: String = ""
    var avatarUrl: String?
    
    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
    
    struct OrgInfo: Identifiable, Codable, Equatable {
        let id: String
        let orgDoctorId: String
        let name: String
        let type: String
        let role: String
    }
    
    init() {
        if KeychainHelper.load(key: "access_token") != nil {
            isAuthenticated = true
            restoreDoctorData()
        }
    }
    
    // MARK: - Login
    
    func login(email: String, password: String) async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        do {
            let body: [String: String] = ["email": email, "password": password]
            let data = try JSONSerialization.data(withJSONObject: body)
            
            var request = URLRequest(url: URL(string: "\(APIConfig.baseURL)/api/v1/auth/login")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw AuthError.invalidCredentials
            }
            
            let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            try await processLoginResponse(json)
            
        } catch {
            await MainActor.run {
                errorMessage = "Email o contraseña incorrectos"
                isLoading = false
            }
        }
    }
    
    private func processLoginResponse(_ json: [String: Any]?) async throws {
        if let accessToken = json?["accessToken"] as? String,
           let refreshToken = json?["refreshToken"] as? String {
            KeychainHelper.save(key: "access_token", value: accessToken)
            KeychainHelper.save(key: "refresh_token", value: refreshToken)
        }
        
        var orgs: [OrgInfo] = []
        if let orgArray = json?["organizations"] as? [[String: Any]] {
            orgs = orgArray.compactMap { o in
                guard let id = (o["org_id"] as? String) ?? (o["orgId"] as? String),
                      let name = (o["org_name"] as? String) ?? (o["name"] as? String)
                else { return nil }
                return OrgInfo(
                    id: id,
                    orgDoctorId: (o["org_doctor_id"] as? String) ?? "",
                    name: name,
                    type: (o["org_type"] as? String) ?? (o["type"] as? String) ?? "individual",
                    role: (o["role"] as? String) ?? "doctor"
                )
            }
        }
        
        let doc = json?["doctor"] as? [String: Any]
        let dId = doc?["id"] as? String ?? ""
        let fName = (doc?["first_name"] as? String) ?? (doc?["firstName"] as? String) ?? ""
        let lName = (doc?["last_name"] as? String) ?? (doc?["lastName"] as? String) ?? ""
        let mail = doc?["email"] as? String ?? ""
        let spec = doc?["specialty"] as? String ?? "Clínica médica"
        let lic = (doc?["medical_license"] as? String) ?? (doc?["medicalLicense"] as? String) ?? ""
        let avatar = (doc?["avatar_url"] as? String) ?? (doc?["avatarUrl"] as? String)
        
        await MainActor.run {
            self.doctorId = dId
            self.firstName = fName
            self.lastName = lName
            self.email = mail
            self.specialty = spec
            self.medicalLicense = lic
            self.avatarUrl = avatar
            self.organizations = orgs
            self.activeOrganization = orgs.first
            self.isAuthenticated = true
            self.isLoading = false
            self.persistDoctorData()
        }
    }
    
    // MARK: - OAuth
    
    func loginWithApple(identityToken: String, authorizationCode: String,
                        fullName: PersonNameComponents?, email: String?) async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        do {
            var body: [String: Any] = [
                "identityToken": identityToken,
                "authorizationCode": authorizationCode
            ]
            if let name = fullName {
                body["fullName"] = ["givenName": name.givenName ?? "", "familyName": name.familyName ?? ""]
            }
            if let email { body["email"] = email }
            
            let data = try JSONSerialization.data(withJSONObject: body)
            var request = URLRequest(url: URL(string: "\(APIConfig.baseURL)/api/v1/auth/apple")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw AuthError.invalidCredentials
            }
            let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            try await processLoginResponse(json)
        } catch {
            await MainActor.run {
                errorMessage = "Error con Apple Sign-In"
                isLoading = false
            }
        }
    }
    
    func loginWithGoogle() async {
        await MainActor.run {
            errorMessage = "Google Sign-In: configurar SDK"
            isLoading = false
        }
    }
    
    // MARK: - Session
    
    func logout() {
        KeychainHelper.delete(key: "access_token")
        KeychainHelper.delete(key: "refresh_token")
        UserDefaults.standard.removeObject(forKey: "doctor_data")
        isAuthenticated = false
        organizations = []
        activeOrganization = nil
        firstName = ""; lastName = ""; email = ""; medicalLicense = ""
    }
    
    func selectOrganization(_ org: OrgInfo) {
        activeOrganization = org
        UserDefaults.standard.set(org.id, forKey: "active_org_id")
    }
    
    // MARK: - Profile image
    
    func saveProfileImage(_ data: Data) {
        UserDefaults.standard.set(data, forKey: "profile_image")
    }
    
    func loadProfileImage() -> Data? {
        UserDefaults.standard.data(forKey: "profile_image")
    }
    
    // MARK: - Persistence
    
    private func persistDoctorData() {
        let dict: [String: Any] = [
            "doctorId": doctorId, "firstName": firstName, "lastName": lastName,
            "email": email, "specialty": specialty, "medicalLicense": medicalLicense,
            "avatarUrl": avatarUrl ?? "",
            "organizations": organizations.map {
                ["id": $0.id, "orgDoctorId": $0.orgDoctorId, "name": $0.name, "type": $0.type, "role": $0.role]
            }
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict) {
            UserDefaults.standard.set(data, forKey: "doctor_data")
        }
    }
    
    private func restoreDoctorData() {
        guard let data = UserDefaults.standard.data(forKey: "doctor_data"),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        
        doctorId = dict["doctorId"] as? String ?? ""
        firstName = dict["firstName"] as? String ?? ""
        lastName = dict["lastName"] as? String ?? ""
        email = dict["email"] as? String ?? ""
        specialty = dict["specialty"] as? String ?? "Clínica médica"
        medicalLicense = dict["medicalLicense"] as? String ?? ""
        let av = dict["avatarUrl"] as? String
        avatarUrl = (av?.isEmpty ?? true) ? nil : av
        
        if let orgArray = dict["organizations"] as? [[String: String]] {
            organizations = orgArray.compactMap { o in
                guard let id = o["id"], let name = o["name"] else { return nil }
                return OrgInfo(id: id, orgDoctorId: o["orgDoctorId"] ?? "",
                               name: name, type: o["type"] ?? "individual", role: o["role"] ?? "doctor")
            }
            let savedId = UserDefaults.standard.string(forKey: "active_org_id")
            activeOrganization = organizations.first { $0.id == savedId } ?? organizations.first
        }
    }
    
    var needsLicense: Bool { medicalLicense.isEmpty || medicalLicense.hasPrefix("PENDING_") }
    
    func updateLicense(license: String, specialty: String) async {
        guard let token = KeychainHelper.load(key: "access_token") else { return }
        do {
            let body: [String: String] = ["medicalLicense": license, "specialty": specialty]
            let data = try JSONSerialization.data(withJSONObject: body)
            var request = URLRequest(url: URL(string: "\(APIConfig.baseURL)/api/v1/profile")!)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = data
            _ = try await URLSession.shared.data(for: request)
            await MainActor.run {
                self.medicalLicense = license
                self.specialty = specialty
                self.persistDoctorData()
            }
        } catch { }
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
