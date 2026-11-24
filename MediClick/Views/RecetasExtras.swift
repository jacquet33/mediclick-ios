import SwiftUI
import SwiftData

// MARK: - Recetas emitidas en el servidor (web, otro dispositivo) → base local

struct RemoteRx: Decodable {
    let id: UUID
    let patientId: UUID
    let status: String?
    let diagnosis: String?
    let diagnosisCode: String?
    let issuedAt: Date?
    let expiresAt: Date?
    let verificationCode: String?
    let notes: String?
    let items: [RemoteRxItem]?
}

struct RemoteRxItem: Decodable {
    let medicationName: String?
    let genericName: String?
    let dosage: String?
    let frequency: String?
    let duration: String?
    let quantity: Int?
    let presentation: String?
    let pharmaceuticalForm: String?
}

enum RecetasSync {
    /// Trae las recetas del servidor y crea o actualiza las locales (por remoteId). Las de pacientes
    /// que todavía no están en el teléfono se omiten hasta que se sincronicen los pacientes.
    @MainActor
    static func sincronizar(_ context: ModelContext) async {
        guard let remotas: [RemoteRx] = try? await APIClient.shared.get("/api/v1/prescriptions") else { return }
        let locales = (try? context.fetch(FetchDescriptor<LocalPrescription>())) ?? []
        let pacientes = (try? context.fetch(FetchDescriptor<LocalPatient>())) ?? []
        var porRemoto: [UUID: LocalPrescription] = [:]
        for rx in locales { if let r = rx.remoteId { porRemoto[r] = rx } }
        var pacientePorRemoto: [UUID: LocalPatient] = [:]
        for p in pacientes { if let r = p.remoteId { pacientePorRemoto[r] = p } }

        for r in remotas {
            if let local = porRemoto[r.id] {
                if let s = r.status, local.status != s { local.status = s }
                local.lastSyncedAt = Date()
                continue
            }
            guard let paciente = pacientePorRemoto[r.patientId] else { continue }
            let rx = LocalPrescription(doctorId: UUID(), patient: paciente, diagnosis: r.diagnosis ?? "",
                                       expiresAt: r.expiresAt ?? Date())
            rx.remoteId = r.id
            rx.syncStatus = .synced
            rx.lastSyncedAt = Date()
            rx.status = r.status ?? "active"
            rx.diagnosisCode = r.diagnosisCode
            rx.verificationCode = r.verificationCode
            rx.notes = r.notes
            if let f = r.issuedAt { rx.issuedAt = f; rx.createdAt = f }
            context.insert(rx)
            for (n, i) in (r.items ?? []).enumerated() {
                let item = LocalPrescriptionItem(prescription: rx, medicationName: i.medicationName ?? "",
                                                 dosage: i.dosage ?? "", frequency: i.frequency ?? "")
                item.genericName = i.genericName
                item.duration = i.duration
                item.quantity = i.quantity
                item.presentation = i.presentation
                item.pharmaceuticalForm = i.pharmaceuticalForm
                item.sortOrder = n
                context.insert(item)
            }
        }
        try? context.save()
    }
}

// MARK: - Datos para precargar una receta nueva (repetir receta)

struct RxPrefill {
    var patient: LocalPatient?
    var diagnosis: String
    var diagnosisCode: String?
    var items: [Item]

    struct Item {
        var name: String
        var genericName: String?
        var dosage: String
        var frequency: String
        var duration: String?
        var presentation: String?
        var pharmaceuticalForm: String?
    }

    init(desde rx: LocalPrescription) {
        patient = rx.patient
        diagnosis = rx.diagnosis
        diagnosisCode = rx.diagnosisCode
        items = (rx.items ?? []).sorted { $0.sortOrder < $1.sortOrder }.map {
            Item(name: $0.medicationName, genericName: $0.genericName, dosage: $0.dosage, frequency: $0.frequency,
                 duration: $0.duration, presentation: $0.presentation, pharmaceuticalForm: $0.pharmaceuticalForm)
        }
    }
}

// MARK: - Guardar la receta actual como plantilla

struct NuevaPlantillaRequest: Encodable {
    let name: String
    let category: String?
    let diagnosis: String?
    let diagnosisCode: String?
    let items: [Item]
    struct Item: Encodable {
        let medicationName: String
        let dosage: String?
        let frequency: String?
        let duration: String?
    }
}

struct PlantillaCreada: Decodable { let id: String? }

struct GuardarPlantillaSheet: View {
    let request: (String, String?) -> NuevaPlantillaRequest
    @Environment(\.dismiss) private var dismiss
    @State private var nombre = ""
    @State private var categoria = ""
    @State private var guardando = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre (ej: Faringitis adulto)", text: $nombre)
                    TextField("Categoría (opcional)", text: $categoria)
                } footer: {
                    Text("Guarda el diagnóstico y los medicamentos para usarlos en las próximas recetas.")
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Guardar plantilla")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(guardando ? "Guardando…" : "Guardar") { Task { await guardar() } }
                        .disabled(guardando || nombre.trimmingCharacters(in: .whitespaces).count < 3)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func guardar() async {
        guardando = true
        error = nil
        let cat = categoria.trimmingCharacters(in: .whitespaces)
        do {
            let _: PlantillaCreada = try await APIClient.shared.post("/api/v1/prescription-templates",
                                                                     body: request(nombre.trimmingCharacters(in: .whitespaces), cat.isEmpty ? nil : cat))
            dismiss()
        } catch {
            self.error = "No se pudo guardar la plantilla. Revisá la conexión."
            guardando = false
        }
    }
}
