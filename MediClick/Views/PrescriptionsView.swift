import SwiftUI
import SwiftData

struct PrescriptionsView: View {
    @Query(sort: \LocalPrescription.issuedAt, order: .reverse) private var prescriptions: [LocalPrescription]
    @State private var showNewPrescription = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(prescriptions) { rx in
                    NavigationLink {
                        PrescriptionDetailView(prescription: rx)
                    } label: {
                        PrescriptionRow(prescription: rx)
                    }
                }
            }
            .navigationTitle("Recetas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewPrescription = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .overlay {
                if prescriptions.isEmpty {
                    ContentUnavailableView {
                        Label("Sin recetas", systemImage: "doc.text")
                    } description: {
                        Text("Las recetas emitidas aparecerán acá")
                    }
                }
            }
            .sheet(isPresented: $showNewPrescription) {
                NewPrescriptionView()
            }
        }
    }
}

struct PrescriptionRow: View {
    let prescription: LocalPrescription
    
    var statusColor: Color {
        switch prescription.status {
        case "active": return .green
        case "expired": return .red
        case "cancelled": return .gray
        default: return .gray
        }
    }
    
    var statusLabel: String {
        switch prescription.status {
        case "active": return "Vigente"
        case "expired": return "Vencida"
        case "cancelled": return "Cancelada"
        default: return prescription.status
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(prescription.items?.first?.medicationName ?? "Receta")
                    .font(.body.weight(.medium))
                Spacer()
                Text(statusLabel)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.12))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }
            
            if let item = prescription.items?.first {
                Text("\(item.frequency) — \(item.duration ?? "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text(prescription.patient?.fullName ?? "")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(prescription.issuedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PrescriptionDetailView: View {
    let prescription: LocalPrescription
    
    var body: some View {
        List {
            Section("Paciente") {
                if let patient = prescription.patient {
                    HStack {
                        PatientAvatar(name: patient.fullName, size: 40)
                        Text(patient.fullName).font(.headline)
                    }
                }
            }
            
            Section("Diagnóstico") {
                Text(prescription.diagnosis)
                if let code = prescription.diagnosisCode {
                    LabeledContent("CIE-10", value: code)
                }
            }
            
            Section("Medicamentos") {
                ForEach(prescription.items ?? [], id: \.id) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.medicationName)
                            .font(.body.weight(.medium))
                        Text("\(item.dosage) · \(item.frequency)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let duration = item.duration {
                            Text("Duración: \(duration)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        if let instructions = item.instructions {
                            Text(instructions)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section("Verificación") {
                if let code = prescription.verificationCode {
                    LabeledContent("Código", value: code)
                        .font(.body.monospaced())
                }
                LabeledContent("Emitida", value: prescription.issuedAt.formatted(date: .long, time: .shortened))
                LabeledContent("Vence", value: prescription.expiresAt.formatted(date: .long, time: .omitted))
            }
        }
        .navigationTitle("Receta")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NewPrescriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalPatient.lastName) private var patients: [LocalPatient]
    
    @State private var selectedPatient: LocalPatient?
    @State private var diagnosis = ""
    @State private var diagnosisCode = ""
    @State private var medicationName = ""
    @State private var dosage = ""
    @State private var frequency = ""
    @State private var duration = ""
    @State private var daysValid = 30
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Paciente") {
                    Picker("Seleccionar", selection: $selectedPatient) {
                        Text("Elegir...").tag(nil as LocalPatient?)
                        ForEach(patients) { p in
                            Text(p.fullName).tag(p as LocalPatient?)
                        }
                    }
                }
                Section("Diagnóstico") {
                    TextField("Diagnóstico *", text: $diagnosis)
                    TextField("Código CIE-10", text: $diagnosisCode)
                }
                Section("Medicamento") {
                    TextField("Nombre *", text: $medicationName)
                    TextField("Dosis (ej: 10mg) *", text: $dosage)
                    TextField("Frecuencia (ej: 1 comp cada 12hs) *", text: $frequency)
                    TextField("Duración (ej: 30 días)", text: $duration)
                    Stepper("Validez: \(daysValid) días", value: $daysValid, in: 1...365)
                }
                Section {
                    Button("Emitir receta") { save() }
                        .frame(maxWidth: .infinity)
                        .disabled(selectedPatient == nil || diagnosis.isEmpty || medicationName.isEmpty || dosage.isEmpty || frequency.isEmpty)
                }
            }
            .navigationTitle("Nueva receta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
    
    private func save() {
        guard let patient = selectedPatient else { return }
        let expiresAt = Calendar.current.date(byAdding: .day, value: daysValid, to: Date()) ?? Date()
        let rx = LocalPrescription(doctorId: UUID(), patient: patient, diagnosis: diagnosis, expiresAt: expiresAt)
        rx.diagnosisCode = diagnosisCode.isEmpty ? nil : diagnosisCode
        
        let item = LocalPrescriptionItem(prescription: rx, medicationName: medicationName, dosage: dosage, frequency: frequency)
        item.duration = duration.isEmpty ? nil : duration
        
        modelContext.insert(rx)
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}
