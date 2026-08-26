import Foundation
import Observation

// MARK: - Modelos

struct Insurer: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let shortName: String?
    let kind: String?
    let province: String?

    var display: String { shortName ?? name }
}

struct NomenclatorVersion: Decodable, Identifiable {
    let id: String
    let name: String
    let insurerId: String?
    let insurerName: String?
    let source: String?
    let validFrom: Date
    let validTo: Date?
    let unitValue: Decimal?
    let itemCount: Int?
    let itemsWithoutValue: Int?

    var isCurrent: Bool {
        let now = Date()
        return validFrom <= now && (validTo == nil || validTo! >= now)
    }

    var periodLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        f.locale = Locale(identifier: "es_AR")
        let from = f.string(from: validFrom).capitalized
        guard let to = validTo else { return "Desde \(from)" }
        return "\(from) — \(f.string(from: to).capitalized)"
    }
}

struct NomenclatorItem: Decodable, Identifiable {
    let id: String
    let code: String
    let description: String
    let specialty: String?
    let amount: Decimal?
    let professionalUnits: Decimal?
    let operativeUnits: Decimal?
    let requiresAuthorization: Bool?
    let requiresDiagnosis: Bool?
    let coinsurance: Decimal?
}

struct ImportResult: Decodable {
    let nomenclatorId: String
    let inserted: Int
    let updated: Int
    let skipped: Int
    let warnings: [String]
}

struct BillingBatch: Decodable, Identifiable {
    let id: String
    let insurerId: String
    let insurerName: String?
    let insurerShort: String?
    let periodYear: Int
    let periodMonth: Int
    let batchNumber: String?
    let status: String
    let totalItems: Int?
    let totalAmount: Decimal?
    let itemCount: Int?
    let blockedCount: Int?
    let warningCount: Int?
    let submittedAt: Date?

    var periodLabel: String {
        let months = ["", "Enero","Febrero","Marzo","Abril","Mayo","Junio",
                      "Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"]
        let m = periodMonth >= 1 && periodMonth <= 12 ? months[periodMonth] : "\(periodMonth)"
        return "\(m) \(periodYear)"
    }

    var statusLabel: String {
        switch status {
        case "draft": return "Borrador"
        case "audited": return "Auditado"
        case "submitted": return "Presentado"
        case "accepted": return "Aceptado"
        case "rejected": return "Rechazado"
        case "paid": return "Cobrado"
        default: return status.capitalized
        }
    }

    var hasBlockers: Bool { (blockedCount ?? 0) > 0 }
}

struct BillingBatchDetail: Decodable {
    let id: String
    let insurerId: String
    let insurerName: String?
    let periodYear: Int
    let periodMonth: Int
    let status: String
    let totalItems: Int?
    let totalAmount: Decimal?
    let items: [BillingItem]
}

struct BillingItem: Decodable, Identifiable {
    let id: String
    let firstName: String
    let lastName: String
    let dni: String?
    let serviceDate: Date
    let nomenclatorCode: String
    let description: String?
    let quantity: Int
    let unitAmount: Decimal?
    let totalAmount: Decimal?
    let affiliateNumber: String?
    let diagnosisCode: String?
    let authorizationCode: String?
    let auditStatus: String
    let auditNotes: [String]?

    var patientName: String { "\(lastName), \(firstName)" }
    var isBlocked: Bool { auditStatus == "blocked" }
    var hasWarning: Bool { auditStatus == "warning" }
}

struct AuditResult: Decodable {
    let total: Int
    let ok: Int
    let warning: Int
    let blocked: Int
    let canSubmit: Bool
    let findings: [AuditFinding]
}

struct AuditFinding: Decodable, Identifiable {
    let note: String
    let count: Int
    var id: String { note }
}

struct BuildBatchResult: Decodable {
    let batchId: String
    let appointmentsFound: Int
    let itemsAdded: Int
    let skipped: [String]
    let audit: AuditResult
}

// MARK: - Store

@Observable
final class BillingStore {
    var batches: [BillingBatch] = []
    var nomenclators: [NomenclatorVersion] = []
    var insurers: [Insurer] = []

    var isLoading = false
    var errorMessage: String?

    private let api = APIClient.shared

    // ─── Lotes ────────────────────────────────────────────

    func loadBatches(year: Int? = nil) async {
        await run {
            self.batches = try await self.api.get(
                "/api/v1/billing/batches",
                query: ["year": year.map(String.init)]
            )
        }
    }

    func loadBatch(_ id: String) async -> BillingBatchDetail? {
        await runReturning {
            try await self.api.get("/api/v1/billing/batches/\(id)")
        }
    }

    func buildBatch(insurerId: String, year: Int, month: Int) async -> BuildBatchResult? {
        await runReturning {
            struct Body: Encodable {
                let insurerId: String
                let periodYear: Int
                let periodMonth: Int
            }
            return try await self.api.post(
                "/api/v1/billing/batches/build",
                body: Body(insurerId: insurerId, periodYear: year, periodMonth: month)
            )
        }
    }

    func audit(_ batchId: String) async -> AuditResult? {
        await runReturning {
            try await self.api.post("/api/v1/billing/batches/\(batchId)/audit")
        }
    }

    func submit(_ batchId: String, batchNumber: String?) async -> Bool {
        let ok: EmptyResponse? = await runReturning {
            struct Body: Encodable { let batchNumber: String? }
            return try await self.api.post(
                "/api/v1/billing/batches/\(batchId)/submit",
                body: Body(batchNumber: batchNumber)
            )
        }
        return ok != nil
    }

    func removeItem(batchId: String, itemId: String) async -> Bool {
        let ok: EmptyResponse? = await runReturning {
            try await self.api.delete("/api/v1/billing/batches/\(batchId)/items/\(itemId)")
        }
        return ok != nil
    }

    func exportCsv(_ batchId: String) async -> URL? {
        do {
            let data = try await api.download("/api/v1/billing/batches/\(batchId)/export")
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("lote-\(batchId.prefix(8)).csv")
            try data.write(to: url)
            return url
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
            return nil
        }
    }

    // ─── Nomencladores ────────────────────────────────────

    func loadNomenclators(insurerId: String? = nil) async {
        await run {
            self.nomenclators = try await self.api.get(
                "/api/v1/nomenclators",
                query: ["insurer_id": insurerId]
            )
        }
    }

    func createNomenclator(
        name: String, insurerId: String, validFrom: Date, unitValue: Decimal?
    ) async -> NomenclatorVersion? {
        await runReturning {
            struct Body: Encodable {
                let name: String
                let insurerId: String
                let validFrom: String
                let unitValue: Decimal?
                let source: String
            }
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return try await self.api.post(
                "/api/v1/nomenclators",
                body: Body(
                    name: name, insurerId: insurerId,
                    validFrom: f.string(from: validFrom),
                    unitValue: unitValue, source: "convenio"
                )
            )
        }
    }

    func importSheet(nomenclatorId: String, csv: String) async -> ImportResult? {
        await runReturning {
            struct Body: Encodable { let csv: String }
            return try await self.api.post(
                "/api/v1/nomenclators/\(nomenclatorId)/import",
                body: Body(csv: csv)
            )
        }
    }

    func searchCodes(insurerId: String, query: String) async -> [NomenclatorItem] {
        (try? await api.get(
            "/api/v1/nomenclators/search",
            query: ["insurer_id": insurerId, "q": query]
        )) ?? []
    }

    // ─── Financiadores ────────────────────────────────────

    /// Los financiadores con los que el consultorio ya trabaja,
    /// deducidos de las obras sociales cargadas en los pacientes.
    func loadInsurersInUse() async {
        await run {
            self.insurers = try await self.api.get("/api/v1/patients/insurers")
        }
    }

    // ─── Helpers ──────────────────────────────────────────

    private func run(_ work: @escaping () async throws -> Void) async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            try await work()
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }

    private func runReturning<T>(_ work: @escaping () async throws -> T) async -> T? {
        await MainActor.run { isLoading = true; errorMessage = nil }
        defer { Task { @MainActor in self.isLoading = false } }
        do {
            return try await work()
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
            return nil
        }
    }
}

// MARK: - Formato

extension Decimal {
    var pesos: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "$"
        f.locale = Locale(identifier: "es_AR")
        f.maximumFractionDigits = 2
        return f.string(from: self as NSDecimalNumber) ?? "$0"
    }
}

extension Optional where Wrapped == Decimal {
    var pesos: String { self?.pesos ?? "$0" }
}
