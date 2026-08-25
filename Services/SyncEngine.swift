// ============================================================
// MediClick - Sync Engine (iOS)
// Motor de sincronización offline-first
// Local SQLite (SwiftData) ↔ PostgreSQL (REST API)
// ============================================================

import Foundation
import SwiftData
import Network
import OSLog

/// Estado de la conexión de red
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.mediclick.network")
    
    var isConnected: Bool = false
    var connectionType: NWInterface.InterfaceType?
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        monitor.start(queue: queue)
    }
}

// MARK: - API Client

actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let logger = Logger(subsystem: "com.mediclick", category: "API")
    
    // Tokens gestionados via Keychain
    private var accessToken: String?
    private var refreshToken: String?
    
    init(baseURL: String) {
        self.baseURL = URL(string: baseURL)!
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }
    
    func setTokens(access: String, refresh: String) {
        self.accessToken = access
        self.refreshToken = refresh
    }
    
    /// Request genérico con auto-refresh de token
    func request<T: Decodable>(
        method: String,
        path: String,
        body: Encodable? = nil,
        queryParams: [String: String]? = nil
    ) async throws -> T {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        
        if let params = queryParams {
            urlComponents.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // Si el token expiró, intentar refresh
        if httpResponse.statusCode == 401 {
            let refreshed = try await refreshAccessToken()
            if refreshed {
                // Reintentar con nuevo token
                request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await session.data(for: request)
                guard let retryHttp = retryResponse as? HTTPURLResponse,
                      (200...299).contains(retryHttp.statusCode) else {
                    throw APIError.unauthorized
                }
                return try decodeResponse(retryData)
            }
            throw APIError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            logger.error("API error \(httpResponse.statusCode) on \(path)")
            throw APIError.serverError(statusCode: httpResponse.statusCode, data: data)
        }
        
        return try decodeResponse(data)
    }
    
    private func decodeResponse<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
    
    private func refreshAccessToken() async throws -> Bool {
        guard let rt = refreshToken else { return false }
        
        struct RefreshRequest: Encodable { let refreshToken: String }
        struct RefreshResponse: Decodable { let accessToken: String; let refreshToken: String }
        
        let response: RefreshResponse = try await request(
            method: "POST",
            path: "api/v1/auth/refresh",
            body: RefreshRequest(refreshToken: rt)
        )
        
        self.accessToken = response.accessToken
        self.refreshToken = response.refreshToken
        
        // Guardar en Keychain
        KeychainHelper.save(key: "access_token", value: response.accessToken)
        KeychainHelper.save(key: "refresh_token", value: response.refreshToken)
        
        return true
    }
}

enum APIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case serverError(statusCode: Int, data: Data)
    case networkUnavailable
    case syncConflict(entityId: UUID)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Respuesta inválida del servidor"
        case .unauthorized: return "Sesión expirada. Iniciá sesión de nuevo."
        case .serverError(let code, _): return "Error del servidor (\(code))"
        case .networkUnavailable: return "Sin conexión a internet"
        case .syncConflict(let id): return "Conflicto de sincronización en \(id)"
        }
    }
}

// MARK: - Sync Engine

@Observable
final class SyncEngine {
    static let shared = SyncEngine()
    
    private let api: APIClient
    private let logger = Logger(subsystem: "com.mediclick", category: "Sync")
    
    var isSyncing: Bool = false
    var lastSyncDate: Date?
    var pendingChanges: Int = 0
    var syncErrors: [String] = []
    
    private init() {
        // URL configurable - cambiar por tu servidor
        self.api = APIClient(baseURL: "https://api.mediclick.local")
    }
    
    /// Sincronización completa: sube pendientes → baja cambios del servidor
    @MainActor
    func fullSync(modelContext: ModelContext) async {
        guard NetworkMonitor.shared.isConnected else {
            logger.info("Sync skipped: no network")
            return
        }
        
        guard !isSyncing else { return }
        isSyncing = true
        syncErrors = []
        
        defer { isSyncing = false }
        
        do {
            // 1. Subir cambios locales pendientes
            try await uploadPendingPatients(context: modelContext)
            try await uploadPendingAppointments(context: modelContext)
            try await uploadPendingPrescriptions(context: modelContext)
            try await uploadPendingMessages(context: modelContext)
            
            // 2. Bajar cambios del servidor
            try await downloadPatients(context: modelContext)
            try await downloadAppointments(context: modelContext)
            try await downloadPrescriptions(context: modelContext)
            try await downloadMessages(context: modelContext)
            
            // 3. Guardar contexto
            try modelContext.save()
            
            lastSyncDate = Date()
            updatePendingCount(context: modelContext)
            
            logger.info("Full sync completed")
        } catch {
            logger.error("Sync failed: \(error.localizedDescription)")
            syncErrors.append(error.localizedDescription)
        }
    }
    
    // MARK: - Upload (Local → Server)
    
    @MainActor
    private func uploadPendingPatients(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<LocalPatient>(
            predicate: #Predicate { $0.syncStatus == .pendingUpload }
        )
        let pending = try context.fetch(descriptor)
        
        for patient in pending {
            do {
                let remotePatient: RemotePatient = try await api.request(
                    method: patient.remoteId == nil ? "POST" : "PUT",
                    path: patient.remoteId == nil
                        ? "api/v1/patients"
                        : "api/v1/patients/\(patient.remoteId!.uuidString)",
                    body: patient.toRemoteDTO()
                )
                
                patient.remoteId = remotePatient.id
                patient.syncStatus = .synced
                patient.lastSyncedAt = Date()
                
                logger.debug("Synced patient: \(patient.fullName)")
            } catch {
                logger.error("Failed to sync patient \(patient.fullName): \(error)")
                syncErrors.append("Paciente \(patient.fullName): \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func uploadPendingAppointments(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<LocalAppointment>(
            predicate: #Predicate { $0.syncStatus == .pendingUpload }
        )
        let pending = try context.fetch(descriptor)
        
        for appt in pending {
            do {
                let remote: RemoteAppointment = try await api.request(
                    method: appt.remoteId == nil ? "POST" : "PUT",
                    path: appt.remoteId == nil
                        ? "api/v1/appointments"
                        : "api/v1/appointments/\(appt.remoteId!.uuidString)",
                    body: appt.toRemoteDTO()
                )
                appt.remoteId = remote.id
                appt.syncStatus = .synced
                appt.lastSyncedAt = Date()
            } catch {
                syncErrors.append("Turno: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func uploadPendingPrescriptions(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<LocalPrescription>(
            predicate: #Predicate { $0.syncStatus == .pendingUpload }
        )
        let pending = try context.fetch(descriptor)
        
        for rx in pending {
            do {
                let remote: RemotePrescription = try await api.request(
                    method: rx.remoteId == nil ? "POST" : "PUT",
                    path: rx.remoteId == nil
                        ? "api/v1/prescriptions"
                        : "api/v1/prescriptions/\(rx.remoteId!.uuidString)",
                    body: rx.toRemoteDTO()
                )
                rx.remoteId = remote.id
                rx.syncStatus = .synced
                rx.lastSyncedAt = Date()
            } catch {
                syncErrors.append("Receta: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func uploadPendingMessages(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<LocalMessage>(
            predicate: #Predicate { $0.syncStatus == .pendingUpload }
        )
        let pending = try context.fetch(descriptor)
        
        for msg in pending {
            do {
                let remote: RemoteMessage = try await api.request(
                    method: "POST",
                    path: "api/v1/messages",
                    body: msg.toRemoteDTO()
                )
                msg.remoteId = remote.id
                msg.syncStatus = .synced
                msg.lastSyncedAt = Date()
            } catch {
                syncErrors.append("Mensaje: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Download (Server → Local)
    
    @MainActor
    private func downloadPatients(context: ModelContext) async throws {
        let since = lastSyncDate?.iso8601String ?? "2020-01-01T00:00:00Z"
        
        let remotePatients: [RemotePatient] = try await api.request(
            method: "GET",
            path: "api/v1/patients",
            queryParams: ["updated_since": since]
        )
        
        for remote in remotePatients {
            let descriptor = FetchDescriptor<LocalPatient>(
                predicate: #Predicate<LocalPatient> { $0.remoteId == remote.id }
            )
            
            if let existing = try context.fetch(descriptor).first {
                // Solo actualizar si el servidor es más reciente
                if remote.updatedAt > existing.updatedAt && existing.syncStatus == .synced {
                    existing.updateFrom(remote: remote)
                }
            } else {
                // Nuevo paciente del servidor
                let local = LocalPatient.from(remote: remote)
                context.insert(local)
            }
        }
    }
    
    @MainActor
    private func downloadAppointments(context: ModelContext) async throws {
        let since = lastSyncDate?.iso8601String ?? "2020-01-01T00:00:00Z"
        
        let remoteAppts: [RemoteAppointment] = try await api.request(
            method: "GET",
            path: "api/v1/appointments",
            queryParams: ["updated_since": since]
        )
        
        for remote in remoteAppts {
            let descriptor = FetchDescriptor<LocalAppointment>(
                predicate: #Predicate<LocalAppointment> { $0.remoteId == remote.id }
            )
            
            if let existing = try context.fetch(descriptor).first {
                if remote.updatedAt > existing.updatedAt && existing.syncStatus == .synced {
                    existing.updateFrom(remote: remote)
                }
            } else {
                if let local = LocalAppointment.from(remote: remote, context: context) {
                    context.insert(local)
                }
            }
        }
    }
    
    @MainActor
    private func downloadPrescriptions(context: ModelContext) async throws {
        let since = lastSyncDate?.iso8601String ?? "2020-01-01T00:00:00Z"
        
        let remoteRx: [RemotePrescription] = try await api.request(
            method: "GET",
            path: "api/v1/prescriptions",
            queryParams: ["updated_since": since]
        )
        
        for remote in remoteRx {
            let descriptor = FetchDescriptor<LocalPrescription>(
                predicate: #Predicate<LocalPrescription> { $0.remoteId == remote.id }
            )
            
            if let existing = try context.fetch(descriptor).first {
                if remote.updatedAt > existing.updatedAt && existing.syncStatus == .synced {
                    existing.updateFrom(remote: remote)
                }
            } else {
                if let local = LocalPrescription.from(remote: remote, context: context) {
                    context.insert(local)
                }
            }
        }
    }
    
    @MainActor
    private func downloadMessages(context: ModelContext) async throws {
        let since = lastSyncDate?.iso8601String ?? "2020-01-01T00:00:00Z"
        
        let remoteMessages: [RemoteMessage] = try await api.request(
            method: "GET",
            path: "api/v1/messages",
            queryParams: ["since": since]
        )
        
        for remote in remoteMessages {
            let descriptor = FetchDescriptor<LocalMessage>(
                predicate: #Predicate<LocalMessage> { $0.remoteId == remote.id }
            )
            
            if try context.fetch(descriptor).first == nil {
                if let local = LocalMessage.from(remote: remote, context: context) {
                    context.insert(local)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    @MainActor
    private func updatePendingCount(context: ModelContext) {
        do {
            let patients = try context.fetchCount(FetchDescriptor<LocalPatient>(
                predicate: #Predicate { $0.syncStatus == .pendingUpload }
            ))
            let appts = try context.fetchCount(FetchDescriptor<LocalAppointment>(
                predicate: #Predicate { $0.syncStatus == .pendingUpload }
            ))
            let rx = try context.fetchCount(FetchDescriptor<LocalPrescription>(
                predicate: #Predicate { $0.syncStatus == .pendingUpload }
            ))
            let msgs = try context.fetchCount(FetchDescriptor<LocalMessage>(
                predicate: #Predicate { $0.syncStatus == .pendingUpload }
            ))
            pendingChanges = patients + appts + rx + msgs
        } catch {
            pendingChanges = 0
        }
    }
}

// MARK: - Remote DTOs (lo que viene/va del servidor)

struct RemotePatient: Codable {
    let id: UUID
    let firstName: String
    let lastName: String
    let email: String?
    let phone: String?
    let dni: String?
    let dateOfBirth: Date?
    let gender: String
    let bloodType: String
    let insuranceProvider: String?
    let insuranceNumber: String?
    let allergies: [String]
    let chronicConditions: [String]
    let updatedAt: Date
}

struct RemoteAppointment: Codable {
    let id: UUID
    let patientId: UUID
    let date: Date
    let startTime: String
    let endTime: String
    let status: String
    let reason: String?
    let isFirstVisit: Bool
    let updatedAt: Date
}

struct RemotePrescription: Codable {
    let id: UUID
    let patientId: UUID
    let diagnosis: String
    let diagnosisCode: String?
    let status: String
    let issuedAt: Date
    let expiresAt: Date
    let verificationCode: String?
    let items: [RemotePrescriptionItem]?
    let updatedAt: Date
}

struct RemotePrescriptionItem: Codable {
    let id: UUID
    let medicationName: String
    let dosage: String
    let frequency: String
    let duration: String?
    let quantity: Int?
    let instructions: String?
}

struct RemoteMessage: Codable {
    let id: UUID
    let conversationId: UUID
    let senderType: String
    let senderId: UUID
    let messageType: String
    let content: String
    let createdAt: Date
}

// MARK: - Keychain Helper (simplificado)

enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Date Extension

extension Date {
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}
