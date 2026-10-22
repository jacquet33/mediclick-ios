import SwiftUI

// MARK: - Medical Record Models

struct MedicalRecord: Decodable, Identifiable {
    let id: String
    let patientId: String
    let doctorId: String
    let appointmentId: String?
    let chiefComplaint: String
    let presentIllness: String?
    let vitalSigns: VitalSigns?
    let physicalExam: String?
    let diagnosis: String
    let diagnosisCode: String?
    let secondaryDiagnoses: [SecondaryDiagnosis]?
    let treatmentPlan: String?
    let labOrders: [String]?
    let imagingOrders: [String]?
    let referrals: [String]?
    let privateNotes: String?
    let doctorName: String?
    let date: String?
    let createdAt: String?

    // CodingKeys removed — APIClient.decoder uses .convertFromSnakeCase

    var dateFormatted: String {
        let d = date ?? createdAt ?? ""
        let parts = d.prefix(10).split(separator: "-")
        guard parts.count >= 3 else { return String(d.prefix(10)) }
        return "\(parts[2])/\(parts[1])/\(parts[0])"
    }
}

struct VitalSigns: Decodable {
    let bloodPressure: String?
    let heartRate: Int?
    let temperature: Double?
    let respiratoryRate: Int?
    let spO2: Int?
    let weight: Double?
    let height: Double?

    // Custom init below handles both camelCase and snake_case (JSON blob from DB)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        bloodPressure = try container.decodeIfPresent(String.self, forKey: DynamicKey(stringValue: "bloodPressure")!)
            ?? container.decodeIfPresent(String.self, forKey: DynamicKey(stringValue: "blood_pressure")!)
        heartRate = try container.decodeIfPresent(Int.self, forKey: DynamicKey(stringValue: "heartRate")!)
            ?? container.decodeIfPresent(Int.self, forKey: DynamicKey(stringValue: "heart_rate")!)
        temperature = try container.decodeIfPresent(Double.self, forKey: DynamicKey(stringValue: "temperature")!)
        respiratoryRate = try container.decodeIfPresent(Int.self, forKey: DynamicKey(stringValue: "respiratoryRate")!)
            ?? container.decodeIfPresent(Int.self, forKey: DynamicKey(stringValue: "respiratory_rate")!)
        spO2 = try container.decodeIfPresent(Int.self, forKey: DynamicKey(stringValue: "spO2")!)
            ?? container.decodeIfPresent(Int.self, forKey: DynamicKey(stringValue: "sp_o2")!)
        weight = try container.decodeIfPresent(Double.self, forKey: DynamicKey(stringValue: "weight")!)
        height = try container.decodeIfPresent(Double.self, forKey: DynamicKey(stringValue: "height")!)
    }

    var isEmpty: Bool {
        bloodPressure == nil && heartRate == nil && temperature == nil &&
        respiratoryRate == nil && spO2 == nil && weight == nil && height == nil
    }
}

private struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
}

struct SecondaryDiagnosis: Decodable {
    let diagnosis: String
    let code: String?
}

// MARK: - Create / Edit Payload

struct CreateRecordPayload: Encodable {
    let patientId: String
    let appointmentId: String?
    let chiefComplaint: String
    let presentIllness: String?
    let vitalSigns: VitalSignsPayload?
    let physicalExam: String?
    let diagnosis: String
    let diagnosisCode: String?
    let secondaryDiagnoses: [SecondaryDiagnosisPayload]?
    let treatmentPlan: String?
    let labOrders: [String]?
    let imagingOrders: [String]?
    let referrals: [String]?
    let privateNotes: String?
}

struct VitalSignsPayload: Encodable {
    let bloodPressure: String?
    let heartRate: Int?
    let temperature: Double?
    let respiratoryRate: Int?
    let spO2: Int?
    let weight: Double?
    let height: Double?
}

struct SecondaryDiagnosisPayload: Encodable {
    let diagnosis: String
    let code: String?
}

// MARK: - Records List View (embedded in PatientDetail)

struct MedicalRecordsListView: View {
    let patientId: String
    @State private var records: [MedicalRecord] = []
    @State private var isLoading = true
    @State private var showNewRecord = false
    @State private var selectedRecord: MedicalRecord?

    var body: some View {
        VStack(spacing: 12) {
            // Add button
            Button { showNewRecord = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Nueva consulta")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(Color.mediTeal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.mediTeal.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mediTeal.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)

            if isLoading {
                ProgressView().tint(.mediTeal).padding(30)
            } else if records.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text").font(.system(size: 28)).foregroundStyle(Color.mediTextMuted)
                    Text("Sin registros médicos").font(.system(size: 13)).foregroundStyle(Color.mediTextSoft)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(records) { record in
                    Button { selectedRecord = record } label: {
                        recordCard(record)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task { await loadRecords() }
        .sheet(isPresented: $showNewRecord) {
            NewMedicalRecordView(patientId: patientId) {
                Task { await loadRecords() }
            }
        }
        .sheet(item: $selectedRecord) { record in
            MedicalRecordDetailView(record: record, patientId: patientId) {
                Task { await loadRecords() }
            }
        }
    }

    @ViewBuilder
    private func recordCard(_ record: MedicalRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.mediTeal)
                    Text(record.chiefComplaint)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.mediText)
                        .lineLimit(1)
                }
                Spacer()
                Text(record.dateFormatted)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.mediTextMuted)
            }

            HStack(spacing: 6) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.mediWarning)
                Text(record.diagnosis)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.mediTextSoft)
                    .lineLimit(1)
            }

            HStack {
                if let doctor = record.doctorName {
                    Text("Dr. \(doctor)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.mediTextMuted)
                }
                Spacer()

                // Vital signs indicators
                if let vs = record.vitalSigns, !vs.isEmpty {
                    HStack(spacing: 4) {
                        if vs.bloodPressure != nil { vitalDot(.mediDanger) }
                        if vs.heartRate != nil { vitalDot(.mediTeal) }
                        if vs.temperature != nil { vitalDot(.mediWarning) }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.mediTextMuted)
            }
        }
        .padding(14)
        .background(Color.mediSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mediBorder, lineWidth: 0.5))
    }

    private func vitalDot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 6, height: 6)
    }

    private func loadRecords() async {
        do {
            let result: [MedicalRecord] = try await APIClient.shared.get(
                "/api/v1/medical-records?patient_id=\(patientId)"
            )
            await MainActor.run { records = result; isLoading = false }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Record Detail View

struct MedicalRecordDetailView: View {
    let record: MedicalRecord
    let patientId: String
    var onSave: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false

    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "stethoscope")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.mediTeal)
                                Text("Motivo de consulta")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.mediTextMuted)
                            }
                            Text(record.chiefComplaint)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.mediText)

                            HStack(spacing: 12) {
                                if let doctor = record.doctorName {
                                    Label("Dr. \(doctor)", systemImage: "person.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.mediTextSoft)
                                }
                                Label(record.dateFormatted, systemImage: "calendar")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.mediTextSoft)
                            }
                        }
                        .mediElevated()

                        // Present Illness
                        if let pi = record.presentIllness, !pi.isEmpty {
                            detailSection("Enfermedad actual", icon: "waveform.path.ecg", content: pi)
                        }

                        // Vital Signs
                        if let vs = record.vitalSigns, !vs.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                MediSectionHeader(title: "Signos vitales", icon: "heart.fill")

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    if let bp = vs.bloodPressure {
                                        vitalCard("TA", value: bp, unit: "mmHg", color: .mediDanger)
                                    }
                                    if let hr = vs.heartRate {
                                        vitalCard("FC", value: "\(hr)", unit: "bpm", color: .mediTeal)
                                    }
                                    if let temp = vs.temperature {
                                        vitalCard("Temp", value: String(format: "%.1f", temp), unit: "°C", color: .mediWarning)
                                    }
                                    if let rr = vs.respiratoryRate {
                                        vitalCard("FR", value: "\(rr)", unit: "rpm", color: .mediSuccess)
                                    }
                                    if let spo2 = vs.spO2 {
                                        vitalCard("SpO₂", value: "\(spo2)", unit: "%", color: .mediCyan)
                                    }
                                    if let w = vs.weight {
                                        vitalCard("Peso", value: String(format: "%.1f", w), unit: "kg", color: .mediTextSoft)
                                    }
                                    if let h = vs.height {
                                        vitalCard("Talla", value: String(format: "%.0f", h), unit: "cm", color: .mediTextSoft)
                                    }
                                }
                            }
                            .mediElevated()
                        }

                        // Physical Exam
                        if let pe = record.physicalExam, !pe.isEmpty {
                            detailSection("Examen físico", icon: "figure.stand", content: pe)
                        }

                        // Diagnosis
                        VStack(alignment: .leading, spacing: 8) {
                            MediSectionHeader(title: "Diagnóstico", icon: "cross.case.fill")
                            HStack {
                                Text(record.diagnosis)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.mediText)
                                Spacer()
                                if let code = record.diagnosisCode, !code.isEmpty {
                                    MediBadge(code, color: .mediTeal)
                                }
                            }

                            if let secondary = record.secondaryDiagnoses, !secondary.isEmpty {
                                Divider()
                                ForEach(Array(secondary.enumerated()), id: \.offset) { _, dx in
                                    HStack {
                                        Text("• \(dx.diagnosis)")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.mediTextSoft)
                                        Spacer()
                                        if let code = dx.code, !code.isEmpty {
                                            Text(code)
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color.mediTextMuted)
                                        }
                                    }
                                }
                            }
                        }
                        .mediElevated()

                        // Treatment Plan
                        if let tp = record.treatmentPlan, !tp.isEmpty {
                            detailSection("Plan de tratamiento", icon: "list.clipboard.fill", content: tp)
                        }

                        // Orders
                        if let labs = record.labOrders, !labs.isEmpty {
                            ordersSection("Estudios de laboratorio", icon: "flask.fill", items: labs, color: .mediTeal)
                        }

                        if let imaging = record.imagingOrders, !imaging.isEmpty {
                            ordersSection("Estudios por imágenes", icon: "photo.artframe", items: imaging, color: .mediCyan)
                        }

                        if let refs = record.referrals, !refs.isEmpty {
                            ordersSection("Derivaciones", icon: "arrow.triangle.branch", items: refs, color: .mediWarning)
                        }

                        // Private Notes
                        if let notes = record.privateNotes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.mediDanger)
                                    Text("Notas privadas")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.mediDanger)
                                }
                                Text(notes)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.mediTextSoft)
                            }
                            .padding(14)
                            .background(Color.mediDanger.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mediDanger.opacity(0.15), lineWidth: 0.5))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Registro médico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEdit = true } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(Color.mediTeal)
                    }
                }
            }
            .sheet(isPresented: $showEdit) {
                NewMedicalRecordView(patientId: patientId, editing: record) {
                    onSave?()
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func detailSection(_ title: String, icon: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MediSectionHeader(title: title, icon: icon)
            Text(content)
                .font(.system(size: 13))
                .foregroundStyle(Color.mediTextSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .mediElevated()
    }

    @ViewBuilder
    private func vitalCard(_ label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.mediText)
            Text(unit)
                .font(.system(size: 10))
                .foregroundStyle(Color.mediTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func ordersSection(_ title: String, icon: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MediSectionHeader(title: title, icon: icon)
            ForEach(items, id: \.self) { item in
                HStack(spacing: 8) {
                    Circle().fill(color).frame(width: 6, height: 6)
                    Text(item)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.mediTextSoft)
                }
            }
        }
        .mediElevated()
    }
}

// MARK: - New / Edit Medical Record

struct NewMedicalRecordView: View {
    let patientId: String
    var editing: MedicalRecord? = nil
    var onSave: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    // Required
    @State private var chiefComplaint = ""
    @State private var diagnosis = ""

    // Optional text
    @State private var presentIllness = ""
    @State private var physicalExam = ""
    @State private var diagnosisCode = ""
    @State private var treatmentPlan = ""
    @State private var privateNotes = ""

    // Vital signs
    @State private var showVitals = false
    @State private var bloodPressure = ""
    @State private var heartRate = ""
    @State private var temperature = ""
    @State private var respiratoryRate = ""
    @State private var spO2 = ""
    @State private var weight = ""
    @State private var height = ""

    // Orders (comma separated)
    @State private var labOrders = ""
    @State private var imagingOrders = ""
    @State private var referrals = ""

    // Secondary diagnoses
    @State private var secondaryDx = ""

    // State
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var activeSection = 0

    private var isEditing: Bool { editing != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Section picker
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                sectionChip("Consulta", section: 0, icon: "stethoscope")
                                sectionChip("Signos vitales", section: 1, icon: "heart.fill")
                                sectionChip("Diagnóstico", section: 2, icon: "cross.case.fill")
                                sectionChip("Plan", section: 3, icon: "list.clipboard.fill")
                                sectionChip("Notas", section: 4, icon: "lock.fill")
                            }
                            .padding(.horizontal, 4)
                        }

                        // Sections
                        switch activeSection {
                        case 0: consultaSection
                        case 1: vitalsSection
                        case 2: diagnosisSection
                        case 3: planSection
                        case 4: notesSection
                        default: EmptyView()
                        }

                        // Error
                        if let err = errorMessage {
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.mediDanger)
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.mediDanger.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // Save button
                        Button { Task { await save() } } label: {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: isEditing ? "checkmark.circle.fill" : "doc.badge.plus")
                                }
                                Text(isEditing ? "Guardar cambios" : "Crear registro")
                            }
                        }
                        .buttonStyle(MediTealButtonStyle())
                        .disabled(chiefComplaint.isEmpty || diagnosis.isEmpty || isSaving)
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isEditing ? "Editar registro" : "Nueva consulta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    // MARK: - Sections

    private var consultaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MediSectionHeader(title: "Datos de la consulta", icon: "stethoscope")

            VStack(alignment: .leading, spacing: 6) {
                Text("Motivo de consulta *")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.mediTextSoft)
                TextField("Ej: Dolor abdominal, control anual...", text: $chiefComplaint)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Enfermedad actual")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.mediTextSoft)
                TextEditor(text: $presentIllness)
                    .font(.system(size: 14))
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.mediSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mediBorder, lineWidth: 0.5))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Examen físico")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.mediTextSoft)
                TextEditor(text: $physicalExam)
                    .font(.system(size: 14))
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.mediSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mediBorder, lineWidth: 0.5))
            }
        }
        .mediElevated()
    }

    private var vitalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MediSectionHeader(title: "Signos vitales", icon: "heart.fill")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                vitalField("TA (mmHg)", placeholder: "120/80", text: $bloodPressure, icon: "drop.fill", color: .mediDanger)
                vitalField("FC (bpm)", placeholder: "72", text: $heartRate, icon: "heart.fill", color: .mediTeal, keyboard: .numberPad)
                vitalField("Temp (°C)", placeholder: "36.5", text: $temperature, icon: "thermometer", color: .mediWarning, keyboard: .decimalPad)
                vitalField("FR (rpm)", placeholder: "16", text: $respiratoryRate, icon: "lungs.fill", color: .mediSuccess, keyboard: .numberPad)
                vitalField("SpO₂ (%)", placeholder: "98", text: $spO2, icon: "waveform.path.ecg", color: .mediCyan, keyboard: .numberPad)
                vitalField("Peso (kg)", placeholder: "70.0", text: $weight, icon: "scalemass.fill", color: .mediTextSoft, keyboard: .decimalPad)
                vitalField("Talla (cm)", placeholder: "170", text: $height, icon: "ruler", color: .mediTextSoft, keyboard: .numberPad)
            }
        }
        .mediElevated()
    }

    private var diagnosisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MediSectionHeader(title: "Diagnóstico", icon: "cross.case.fill")

            VStack(alignment: .leading, spacing: 6) {
                Text("Diagnóstico principal *")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.mediTextSoft)
                TextField("Ej: Gastritis aguda", text: $diagnosis)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Código CIE-10")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.mediTextSoft)
                TextField("Ej: K29.0", text: $diagnosisCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
                    .autocapitalization(.allCharacters)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Diagnósticos secundarios (uno por línea)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.mediTextSoft)
                TextEditor(text: $secondaryDx)
                    .font(.system(size: 14))
                    .frame(minHeight: 60)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.mediSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mediBorder, lineWidth: 0.5))
            }
        }
        .mediElevated()
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MediSectionHeader(title: "Plan de tratamiento", icon: "list.clipboard.fill")

            VStack(alignment: .leading, spacing: 6) {
                Text("Tratamiento")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.mediTextSoft)
                TextEditor(text: $treatmentPlan)
                    .font(.system(size: 14))
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.mediSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mediBorder, lineWidth: 0.5))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Estudios de laboratorio (separar con coma)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.mediTextSoft)
                TextField("Ej: Hemograma, Glucemia, Urea", text: $labOrders)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Estudios por imágenes (separar con coma)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.mediTextSoft)
                TextField("Ej: Rx tórax, Eco abdominal", text: $imagingOrders)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Derivaciones (separar con coma)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.mediTextSoft)
                TextField("Ej: Cardiología, Nutrición", text: $referrals)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
            }
        }
        .mediElevated()
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.mediDanger)
                Text("Notas privadas")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.mediText)
            }

            Text("Solo visibles para vos. No se incluyen en reportes ni se comparten con el paciente.")
                .font(.system(size: 12))
                .foregroundStyle(Color.mediTextMuted)

            TextEditor(text: $privateNotes)
                .font(.system(size: 14))
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.mediSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mediDanger.opacity(0.2), lineWidth: 0.5))
        }
        .padding(14)
        .background(Color.mediDanger.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mediDanger.opacity(0.1), lineWidth: 0.5))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionChip(_ title: String, section: Int, icon: String) -> some View {
        Button { activeSection = section } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(activeSection == section ? .white : Color.mediTextSoft)
            .background(activeSection == section ? Color.mediTeal : Color.mediSurface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(activeSection == section ? Color.clear : Color.mediBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func vitalField(_ label: String, placeholder: String, text: Binding<String>,
                            icon: String, color: Color, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.mediTextSoft)
            }
            TextField(placeholder, text: text)
                .font(.system(size: 14))
                .keyboardType(keyboard)
                .padding(8)
                .background(Color.mediSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mediBorder, lineWidth: 0.5))
        }
    }

    private func populateIfEditing() {
        guard let r = editing else { return }
        chiefComplaint = r.chiefComplaint
        diagnosis = r.diagnosis
        presentIllness = r.presentIllness ?? ""
        physicalExam = r.physicalExam ?? ""
        diagnosisCode = r.diagnosisCode ?? ""
        treatmentPlan = r.treatmentPlan ?? ""
        privateNotes = r.privateNotes ?? ""

        if let vs = r.vitalSigns {
            bloodPressure = vs.bloodPressure ?? ""
            heartRate = vs.heartRate.map { "\($0)" } ?? ""
            temperature = vs.temperature.map { String(format: "%.1f", $0) } ?? ""
            respiratoryRate = vs.respiratoryRate.map { "\($0)" } ?? ""
            spO2 = vs.spO2.map { "\($0)" } ?? ""
            weight = vs.weight.map { String(format: "%.1f", $0) } ?? ""
            height = vs.height.map { String(format: "%.0f", $0) } ?? ""
        }

        labOrders = r.labOrders?.joined(separator: ", ") ?? ""
        imagingOrders = r.imagingOrders?.joined(separator: ", ") ?? ""
        referrals = r.referrals?.joined(separator: ", ") ?? ""

        if let secondary = r.secondaryDiagnoses {
            secondaryDx = secondary.map { $0.diagnosis }.joined(separator: "\n")
        }
    }

    private func splitComma(_ text: String) -> [String]? {
        let items = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return items.isEmpty ? nil : items
    }

    private func save() async {
        guard !chiefComplaint.isEmpty, !diagnosis.isEmpty else { return }
        isSaving = true
        errorMessage = nil

        let vitals = VitalSignsPayload(
            bloodPressure: bloodPressure.isEmpty ? nil : bloodPressure,
            heartRate: Int(heartRate),
            temperature: Double(temperature),
            respiratoryRate: Int(respiratoryRate),
            spO2: Int(spO2),
            weight: Double(weight),
            height: Double(height)
        )

        let hasVitals = vitals.bloodPressure != nil || vitals.heartRate != nil || vitals.temperature != nil
            || vitals.respiratoryRate != nil || vitals.spO2 != nil || vitals.weight != nil || vitals.height != nil

        let secondaryList: [SecondaryDiagnosisPayload]? = {
            let lines = secondaryDx.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard !lines.isEmpty else { return nil }
            return lines.map { SecondaryDiagnosisPayload(diagnosis: $0, code: nil) }
        }()

        let payload = CreateRecordPayload(
            patientId: patientId,
            appointmentId: nil,
            chiefComplaint: chiefComplaint,
            presentIllness: presentIllness.isEmpty ? nil : presentIllness,
            vitalSigns: hasVitals ? vitals : nil,
            physicalExam: physicalExam.isEmpty ? nil : physicalExam,
            diagnosis: diagnosis,
            diagnosisCode: diagnosisCode.isEmpty ? nil : diagnosisCode,
            secondaryDiagnoses: secondaryList,
            treatmentPlan: treatmentPlan.isEmpty ? nil : treatmentPlan,
            labOrders: splitComma(labOrders),
            imagingOrders: splitComma(imagingOrders),
            referrals: splitComma(referrals),
            privateNotes: privateNotes.isEmpty ? nil : privateNotes
        )

        do {
            if let record = editing {
                let _: MedicalRecord = try await APIClient.shared.put(
                    "/api/v1/medical-records/\(record.id)",
                    body: payload
                )
            } else {
                let _: MedicalRecord = try await APIClient.shared.post(
                    "/api/v1/medical-records",
                    body: payload
                )
            }
            await MainActor.run {
                onSave?()
                dismiss()
            }
        } catch {
            if (error as? APIError)?.requiresLogin == true { return }
            await MainActor.run {
                errorMessage = "No se pudo guardar. Intentá de nuevo."
                isSaving = false
            }
        }
    }
}
