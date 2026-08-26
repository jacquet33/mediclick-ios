import Foundation

/// Cliente HTTP de la app.
///
/// Todas las llamadas al backend pasan por acá. Se encarga de:
/// - adjuntar el token en cada request
/// - mandar la organización activa
/// - renovar el token cuando vence, sin que el médico se entere
/// - reintentar la llamada original después de renovar
actor APIClient {
    static let shared = APIClient()

    private var refreshTask: Task<Bool, Never>?

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 60
        cfg.waitsForConnectivity = true
        return URLSession(configuration: cfg)
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            if let d = ISO8601DateFormatter.withMillis.date(from: s) { return d }
            if let d = ISO8601DateFormatter.plain.date(from: s) { return d }
            if let d = DateFormatter.dateOnly.date(from: s) { return d }
            throw DecodingError.dataCorruptedError(in: try dec.singleValueContainer(),
                                                   debugDescription: "Fecha no reconocida: \(s)")
        }
        return d
    }()

    // MARK: - Request

    func get<T: Decodable>(_ path: String, query: [String: String?] = [:]) async throws -> T {
        try await request(method: "GET", path: path, query: query)
    }

    func post<T: Decodable>(_ path: String, body: Encodable? = nil) async throws -> T {
        try await request(method: "POST", path: path, body: body)
    }

    func put<T: Decodable>(_ path: String, body: Encodable? = nil) async throws -> T {
        try await request(method: "PUT", path: path, body: body)
    }

    func delete<T: Decodable>(_ path: String) async throws -> T {
        try await request(method: "DELETE", path: path)
    }

    /// Para descargas (CSV, PDF)
    func download(_ path: String, query: [String: String?] = [:]) async throws -> Data {
        let (data, response) = try await send(
            build(method: "GET", path: path, query: query, body: nil)
        )
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        if http.statusCode == 401 {
            guard await refreshToken() else { throw APIError.sessionExpired }
            let (retryData, retryResponse) = try await send(
                build(method: "GET", path: path, query: query, body: nil)
            )
            guard let retryHttp = retryResponse as? HTTPURLResponse,
                  (200...299).contains(retryHttp.statusCode) else {
                throw APIError.sessionExpired
            }
            return retryData
        }

        guard (200...299).contains(http.statusCode) else {
            throw APIError.server(status: http.statusCode, message: Self.message(from: data))
        }
        return data
    }

    private func request<T: Decodable>(
        method: String,
        path: String,
        query: [String: String?] = [:],
        body: Encodable? = nil
    ) async throws -> T {
        let (data, response) = try await send(build(method: method, path: path, query: query, body: body))

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        // Token vencido: renovar y reintentar una sola vez
        if http.statusCode == 401 {
            guard await refreshToken() else { throw APIError.sessionExpired }

            let (retryData, retryResponse) = try await send(
                build(method: method, path: path, query: query, body: body)
            )
            guard let retryHttp = retryResponse as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            guard (200...299).contains(retryHttp.statusCode) else {
                if retryHttp.statusCode == 401 { throw APIError.sessionExpired }
                throw APIError.server(status: retryHttp.statusCode, message: Self.message(from: retryData))
            }
            return try decode(retryData)
        }

        if http.statusCode == 403 {
            throw APIError.forbidden(message: Self.message(from: data))
        }

        guard (200...299).contains(http.statusCode) else {
            throw APIError.server(status: http.statusCode, message: Self.message(from: data))
        }

        return try decode(data)
    }

    // MARK: - Armado

    private func build(
        method: String,
        path: String,
        query: [String: String?],
        body: Encodable?
    ) -> URLRequest {
        var comps = URLComponents(string: APIConfig.baseURL + path)!
        let items = query.compactMap { k, v in v.map { URLQueryItem(name: k, value: $0) } }
        if !items.isEmpty { comps.queryItems = items }

        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = KeychainHelper.load(key: "access_token") {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // El backend valida que el médico pertenezca a esta organización
        if let orgId = UserDefaults.standard.string(forKey: "active_org_id") {
            req.setValue(orgId, forHTTPHeaderField: "x-organization-id")
        }

        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let enc = JSONEncoder()
            enc.keyEncodingStrategy = .convertToSnakeCase
            req.httpBody = try? enc.encode(AnyEncodable(body))
        }

        return req
    }

    private func send(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: req)
        } catch let err as URLError {
            throw APIError.network(err.localizedDescription)
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    // MARK: - Refresh

    /// Renueva el token. Si hay varias llamadas en paralelo que
    /// reciben 401, todas esperan al mismo refresh en vez de
    /// disparar uno cada una.
    private func refreshToken() async -> Bool {
        if let existing = refreshTask {
            return await existing.value
        }

        let task = Task<Bool, Never> {
            defer { refreshTask = nil }

            guard let refresh = KeychainHelper.load(key: "refresh_token"),
                  let doctorId = UserDefaults.standard.string(forKey: "doctor_id")
            else { return false }

            var req = URLRequest(url: URL(string: APIConfig.baseURL + "/api/v1/auth/refresh")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "doctorId": doctorId,
                "refreshToken": refresh,
            ])

            do {
                let (data, response) = try await session.data(for: req)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let access = json["accessToken"] as? String
                else { return false }

                KeychainHelper.save(key: "access_token", value: access)
                if let newRefresh = json["refreshToken"] as? String {
                    KeychainHelper.save(key: "refresh_token", value: newRefresh)
                }
                return true
            } catch {
                return false
            }
        }

        refreshTask = task
        return await task.value
    }

    private static func message(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let m = json["message"] as? String { return m }
        if let arr = json["message"] as? [String] { return arr.joined(separator: ". ") }
        return json["error"] as? String
    }
}

// MARK: - Errores

enum APIError: LocalizedError {
    case invalidResponse
    case sessionExpired
    case forbidden(message: String?)
    case server(status: Int, message: String?)
    case network(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Respuesta inesperada del servidor"
        case .sessionExpired:
            return "Tu sesión venció. Iniciá sesión de nuevo."
        case .forbidden(let m):
            return m ?? "No tenés permiso para esta acción"
        case .server(let status, let m):
            return m ?? "Error del servidor (\(status))"
        case .network:
            return "Sin conexión. Revisá tu internet."
        case .decoding:
            return "No pudimos leer la respuesta del servidor"
        }
    }

    /// Si venció la sesión hay que mandar al login
    var requiresLogin: Bool {
        if case .sessionExpired = self { return true }
        return false
    }
}

struct EmptyResponse: Decodable {}

/// Wrapper para poder encodear un Encodable existencial
private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ wrapped: Encodable) {
        encodeFunc = wrapped.encode
    }
    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}

// MARK: - Formatters

private extension ISO8601DateFormatter {
    static let withMillis: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let plain = ISO8601DateFormatter()
}

private extension DateFormatter {
    static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")
        return f
    }()
}
