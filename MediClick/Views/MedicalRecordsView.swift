import SwiftUI

// MARK: - Medical Record Models

struct MedicalRecord: Decodable, Identifiable {
    let id: String
    let patientId: String
    let doctorId: String
    let appointmentId: String?
    let recordType: String?
    let chiefComplaint: String
    let presentIllness: String?
    let personalHistory: String?
    let familyHistory: String?
    let currentMedications: String?
    let allergies: String?
    let habits: String?
    let systemsReview: String?
    let otherSymptoms: String?
    let vitalSigns: VitalSigns?
    let physicalExam: String?
    let findings: String?
    let diagnosis: String
    let diagnosisCode: String?
    let secondaryDiagnoses: [SecondaryDiagnosis]?
    let treatmentPlan: String?
    let instructions: String?
    let labOrders: [String]?
    let imagingOrders: [String]?
    let referrals: [String]?
    let followUp: String?
    let prevention: String?
    let occupation: String?
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
    let waistCircumference: Double?
    let shoulderWidth: Double?

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
        waistCircumference = try container.decodeIfPresent(Double.self, forKey: DynamicKey(stringValue: "waistCircumference")!)
            ?? container.decodeIfPresent(Double.self, forKey: DynamicKey(stringValue: "waist_circumference")!)
        shoulderWidth = try container.decodeIfPresent(Double.self, forKey: DynamicKey(stringValue: "shoulderWidth")!)
            ?? container.decodeIfPresent(Double.self, forKey: DynamicKey(stringValue: "shoulder_width")!)
    }

    var isEmpty: Bool {
        bloodPressure == nil && heartRate == nil && temperature == nil &&
        respiratoryRate == nil && spO2 == nil && weight == nil && height == nil &&
        waistCircumference == nil && shoulderWidth == nil
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
    let recordType: String?
    let chiefComplaint: String
    let presentIllness: String?
    let personalHistory: String?
    let familyHistory: String?
    let currentMedications: String?
    let allergies: String?
    let habits: String?
    let systemsReview: String?
    let otherSymptoms: String?
    let vitalSigns: VitalSignsPayload?
    let physicalExam: String?
    let findings: String?
    let diagnosis: String
    let diagnosisCode: String?
    let secondaryDiagnoses: [SecondaryDiagnosisPayload]?
    let treatmentPlan: String?
    let instructions: String?
    let labOrders: [String]?
    let imagingOrders: [String]?
    let referrals: [String]?
    let followUp: String?
    let prevention: String?
    let occupation: String?
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
    let waistCircumference: Double?
    let shoulderWidth: Double?
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
                    Text("Nueva Historia Clínica")
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

                        // Occupation
                        if let occ = record.occupation, !occ.isEmpty {
                            detailSection("Ocupación", icon: "briefcase.fill", content: occ)
                        }

                        // Present Illness
                        if let pi = record.presentIllness, !pi.isEmpty {
                            detailSection("Enfermedad actual", icon: "waveform.path.ecg", content: pi)
                        }

                        // Personal History
                        if let ph = record.personalHistory, !ph.isEmpty {
                            detailSection("Antecedentes personales", icon: "person.text.rectangle", content: ph)
                        }

                        // Family History
                        if let fh = record.familyHistory, !fh.isEmpty {
                            detailSection("Antecedentes familiares", icon: "figure.2.and.child.holdinghands", content: fh)
                        }

                        // Current Medications
                        if let cm = record.currentMedications, !cm.isEmpty {
                            detailSection("Medicación habitual", icon: "pills.fill", content: cm)
                        }

                        // Allergies
                        if let al = record.allergies, !al.isEmpty {
                            detailSection("Alergias", icon: "exclamationmark.triangle.fill", content: al)
                        }

                        // Habits
                        if let hab = record.habits, !hab.isEmpty {
                            detailSection("Hábitos", icon: "leaf.fill", content: hab)
                        }

                        // Systems Review
                        if let sr = record.systemsReview, !sr.isEmpty {
                            detailSection("Revisión por sistemas", icon: "list.bullet.rectangle", content: sr)
                        }

                        // Other Symptoms
                        if let os = record.otherSymptoms, !os.isEmpty {
                            detailSection("Otros síntomas / negativos", icon: "minus.circle", content: os)
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
                                    if let wc = vs.waistCircumference {
                                        vitalCard("Cintura", value: String(format: "%.0f", wc), unit: "cm", color: .mediPrimary)
                                    }
                                    if let sw = vs.shoulderWidth {
                                        vitalCard("Hombros", value: String(format: "%.0f", sw), unit: "cm", color: .mediPrimary)
                                    }
                                }
                            }
                            .mediElevated()
                        }

                        // Physical Exam
                        if let pe = record.physicalExam, !pe.isEmpty {
                            detailSection("Examen físico evaluado", icon: "figure.stand", content: pe)
                        }

                        // Findings
                        if let f = record.findings, !f.isEmpty {
                            detailSection("Hallazgos", icon: "magnifyingglass", content: f)
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

                        // Instructions
                        if let inst = record.instructions, !inst.isEmpty {
                            detailSection("Indicaciones", icon: "text.badge.checkmark", content: inst)
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

                        // Follow-up
                        if let fu = record.followUp, !fu.isEmpty {
                            detailSection("Seguimiento", icon: "calendar.badge.clock", content: fu)
                        }

                        // Prevention
                        if let prev = record.prevention, !prev.isEmpty {
                            detailSection("Prevención evaluada", icon: "shield.checkered", content: prev)
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
            .navigationTitle("Historia Clínica")
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

    // Record type
    @State private var recordType = "primera_consulta"
    @State private var occupation = ""

    // Required
    @State private var chiefComplaint = ""
    @State private var diagnosis = ""

    // Historia clínica fields
    @State private var presentIllness = ""
    @State private var personalHistory = ""
    @State private var familyHistory = ""
    @State private var currentMedications = ""
    @State private var allergiesText = ""
    @State private var habits = ""
    @State private var systemsReview = ""
    @State private var otherSymptoms = ""
    @State private var physicalExam = ""
    @State private var findings = ""
    @State private var diagnosisCode = ""
    @State private var treatmentPlan = ""
    @State private var instructionsText = ""
    @State private var privateNotes = ""

    // Vital signs
    @State private var bloodPressure = ""
    @State private var heartRate = ""
    @State private var temperature = ""
    @State private var respiratoryRate = ""
    @State private var spO2 = ""
    @State private var weight = ""
    @State private var height = ""
    @State private var waistCircumference = ""
    @State private var shoulderWidth = ""

    // Orders (comma separated)
    @State private var labOrders = ""
    @State private var imagingOrders = ""
    @State private var referrals = ""

    // Follow-up & prevention
    @State private var followUp = ""
    @State private var prevention = ""

    // Secondary diagnoses
    @State private var secondaryDx = ""

    // Antecedentes chips
    @State private var personalHistoryExtra = ""
    @State private var familyHistoryExtra = ""

    // CIE-10 search
    @State private var cie10SearchText = ""
    @State private var cie10Results: [CIE10Code] = []
    @State private var showCIE10Results = false

    // Examen físico checkboxes
    @State private var selectedExamenItems: Set<String> = []
    @State private var examenNotes: [String: String] = [:]  // id -> note text

    // Revisión por sistemas checkboxes
    @State private var selectedRevisionItems: Set<String> = []
    @State private var revisionNotes: [String: String] = [:]  // id -> note text

    // State
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var activeSection = 0

    private var isEditing: Bool { editing != nil }

    private let recordTypes = [
        ("primera_consulta", "Primera consulta"),
        ("seguimiento", "Seguimiento"),
        ("control", "Control"),
        ("urgencia", "Urgencia"),
    ]

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
                                sectionChip("Antecedentes", section: 1, icon: "clock.arrow.circlepath")
                                sectionChip("Examen", section: 2, icon: "figure.stand")
                                sectionChip("Diagnóstico", section: 3, icon: "cross.case.fill")
                                sectionChip("Estudios", section: 4, icon: "flask.fill")
                                sectionChip("Plan", section: 5, icon: "list.clipboard.fill")
                                sectionChip("Notas", section: 6, icon: "lock.fill")
                            }
                            .padding(.horizontal, 4)
                        }

                        // Sections
                        switch activeSection {
                        case 0: consultaSection
                        case 1: antecedentesSection
                        case 2: examenSection
                        case 3: diagnosisSection
                        case 4: estudiosSection
                        case 5: planSection
                        case 6: notesSection
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
            .navigationTitle(isEditing ? "Editar Historia Clínica" : "Historia Clínica")
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

            // Tipo de consulta
            VStack(alignment: .leading, spacing: 6) {
                Text("Tipo de consulta")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.mediTextSoft)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recordTypes, id: \.0) { type in
                            Button {
                                recordType = type.0
                            } label: {
                                Text(type.1)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .foregroundStyle(recordType == type.0 ? .white : Color.mediTextSoft)
                                    .background(recordType == type.0 ? Color.mediTeal : Color.mediSurface)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(recordType == type.0 ? Color.clear : Color.mediBorder, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Ocupación
            VStack(alignment: .leading, spacing: 6) {
                Text("Ocupación")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.mediTextSoft)
                TextField("Ej: Empleado, docente, jubilado...", text: $occupation)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
            }

            // Motivo de consulta
            VStack(alignment: .leading, spacing: 6) {
                Text("Motivo de consulta *")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.mediTextSoft)
                TextField("Ej: Dolor abdominal, control anual...", text: $chiefComplaint)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
            }

            // Enfermedad actual
            hcTextArea("Enfermedad actual", text: $presentIllness)
        }
        .mediElevated()
    }

    private var antecedentesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            MediSectionHeader(title: "Antecedentes", icon: "clock.arrow.circlepath")

            antecedentesPersonalesChips
            antecedentesPersonalesExtra
            antecedentesFamiliaresChips
            antecedentesFamiliaresExtra
            hcTextArea("Medicación habitual", text: $currentMedications)
            hcTextArea("Alergias", text: $allergiesText)
            hcTextArea("Hábitos evaluados", text: $habits, placeholder: "Tabaco, alcohol, ejercicio, dieta...")
        }
        .mediElevated()
    }

    private var antecedentesPersonalesChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Antecedentes personales")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.mediTextSoft)

            ChipFlowLayout(spacing: 8) {
                ForEach(AntecedentesComunes.personales, id: \.self) { condition in
                    ChipToggle(
                        title: condition,
                        isSelected: AntecedentesTexto.contiene(condition, en: personalHistoryExtra)
                    ) {
                        // El chip escribe (o borra) el antecedente en el cuadro de texto de abajo
                        personalHistoryExtra = AntecedentesTexto.alternar(condition, en: personalHistoryExtra)
                    }
                }
            }
        }
    }

    private var antecedentesPersonalesExtra: some View {
        hcTextArea("Detalle de antecedentes personales", text: $personalHistoryExtra, placeholder: "Tocá un antecedente o escribilo acá...")
    }

    private var antecedentesFamiliaresChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Antecedentes familiares")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.mediTextSoft)

            ChipFlowLayout(spacing: 8) {
                ForEach(AntecedentesComunes.familiares, id: \.self) { condition in
                    ChipToggle(
                        title: condition,
                        isSelected: AntecedentesTexto.contiene(condition, en: familyHistoryExtra)
                    ) {
                        // El chip escribe (o borra) el antecedente en el cuadro de texto de abajo
                        familyHistoryExtra = AntecedentesTexto.alternar(condition, en: familyHistoryExtra)
                    }
                }
            }
        }
    }

    private var antecedentesFamiliaresExtra: some View {
        hcTextArea("Detalle de antecedentes familiares", text: $familyHistoryExtra, placeholder: "Tocá un antecedente o escribilo acá (ej: madre, diabetes)...")
    }

    private var examenSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1) Revisión por sistemas (checkboxes)
            revisionSistemasBlock

            // 2) Examen físico por aparatos (checkboxes)
            examenFisicoBlock

            // 3) Signos vitales (numeric fields)
            signosVitalesBlock

            // 4) Hallazgos relevantes
            hcTextArea("Hallazgos relevantes", text: $findings)
        }
        .mediElevated()
    }

    // MARK: - Revisión por sistemas checkboxes

    private var revisionSistemasBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            MediSectionHeader(title: "Revisión por sistemas", icon: "list.bullet.clipboard")
            revisionSistemasChips
            hcTextArea("Otros síntomas / negativos", text: $otherSymptoms, placeholder: "Síntomas negativos relevantes...")
        }
    }

    private var revisionSistemasChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(RevisionSistemasData.items) { item in
                revisionSistemaRow(item)
            }
        }
    }

    private func revisionSistemaRow(_ item: RevisionSistemasItem) -> some View {
        let isSelected = selectedRevisionItems.contains(item.id)
        return VStack(alignment: .leading, spacing: 4) {
            Button {
                if selectedRevisionItems.contains(item.id) {
                    selectedRevisionItems.remove(item.id)
                    revisionNotes.removeValue(forKey: item.id)
                } else {
                    selectedRevisionItems.insert(item.id)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? Color.mediPrimary : Color.mediTextMuted)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.mediText)
                        Text(item.symptoms)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.mediTextMuted)
                    }

                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(isSelected ? Color.mediPrimary.opacity(0.06) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            if isSelected {
                revisionNoteField(for: item.id, placeholder: "Detalles de \(item.label.lowercased())...")
            }
        }
    }

    private func revisionNoteField(for id: String, placeholder: String) -> some View {
        let binding = Binding<String>(
            get: { revisionNotes[id] ?? "" },
            set: { revisionNotes[id] = $0 }
        )
        return TextField(placeholder, text: binding)
            .font(.system(size: 13))
            .padding(8)
            .background(Color.mediSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mediBorder, lineWidth: 0.5))
            .padding(.leading, 34)
    }

    // MARK: - Examen físico checkboxes

    private var examenFisicoBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            MediSectionHeader(title: "Examen físico por aparatos", icon: "figure.stand")
            examenFisicoChips
        }
    }

    private var examenFisicoChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(ExamenFisicoData.items) { item in
                examenFisicoRow(item)
            }
        }
    }

    private func examenFisicoRow(_ item: ExamenFisicoItem) -> some View {
        let isSelected = selectedExamenItems.contains(item.id)
        return VStack(alignment: .leading, spacing: 4) {
            Button {
                if selectedExamenItems.contains(item.id) {
                    selectedExamenItems.remove(item.id)
                    examenNotes.removeValue(forKey: item.id)
                } else {
                    selectedExamenItems.insert(item.id)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? Color.mediTeal : Color.mediTextMuted)

                    Text(item.label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.mediText)

                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(isSelected ? Color.mediTeal.opacity(0.06) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            if isSelected {
                examenNoteField(for: item.id, placeholder: "Hallazgos en \(item.label.lowercased())...")
            }
        }
    }

    private func examenNoteField(for id: String, placeholder: String) -> some View {
        let binding = Binding<String>(
            get: { examenNotes[id] ?? "" },
            set: { examenNotes[id] = $0 }
        )
        return TextField(placeholder, text: binding)
            .font(.system(size: 13))
            .padding(8)
            .background(Color.mediSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mediBorder, lineWidth: 0.5))
            .padding(.leading, 34)
    }

    // MARK: - Signos vitales

    private var signosVitalesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Signos vitales")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.mediTextSoft)
                .padding(.top, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                vitalField("TA (mmHg)", placeholder: "120/80", text: $bloodPressure, icon: "drop.fill", color: .mediDanger)
                vitalField("FC (bpm)", placeholder: "72", text: $heartRate, icon: "heart.fill", color: .mediTeal, keyboard: .numberPad)
                vitalField("Temp (°C)", placeholder: "36.5", text: $temperature, icon: "thermometer", color: .mediWarning, keyboard: .decimalPad)
                vitalField("FR (rpm)", placeholder: "16", text: $respiratoryRate, icon: "lungs.fill", color: .mediSuccess, keyboard: .numberPad)
                vitalField("SpO₂ (%)", placeholder: "98", text: $spO2, icon: "waveform.path.ecg", color: .mediCyan, keyboard: .numberPad)
                vitalField("Peso (kg)", placeholder: "70.0", text: $weight, icon: "scalemass.fill", color: .mediTextSoft, keyboard: .decimalPad)
                vitalField("Talla (cm)", placeholder: "170", text: $height, icon: "ruler", color: .mediTextSoft, keyboard: .numberPad)
                vitalField("Cintura (cm)", placeholder: "85", text: $waistCircumference, icon: "circle.dashed", color: .mediPrimary, keyboard: .decimalPad)
                vitalField("Hombros (cm)", placeholder: "45", text: $shoulderWidth, icon: "figure.arms.open", color: .mediPrimary, keyboard: .decimalPad)
            }
        }
    }

    private var diagnosisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MediSectionHeader(title: "Diagnóstico", icon: "cross.case.fill")

            diagnosisPrincipal
            diagnosisCIE10Search
            diagnosisSecondary
        }
        .mediElevated()
    }

    private var diagnosisPrincipal: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Diagnóstico principal *")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.mediTextSoft)
            TextField("Ej: Gastritis aguda", text: $diagnosis)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14))
        }
    }

    private var diagnosisCIE10Search: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Código CIE-10")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.mediTextSoft)

            HStack(spacing: 8) {
                TextField("Buscar código o diagnóstico...", text: $cie10SearchText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
                    .autocapitalization(.allCharacters)
                    .onChange(of: cie10SearchText) {
                        let results = CIE10Database.search(cie10SearchText)
                        cie10Results = Array(results.prefix(8))
                        showCIE10Results = !cie10Results.isEmpty && cie10SearchText.count >= 2
                    }

                if !diagnosisCode.isEmpty {
                    cie10SelectedBadge
                }
            }

            if showCIE10Results {
                cie10ResultsList
            }

            if !diagnosisCode.isEmpty {
                cie10SelectedRow
            }
        }
    }

    private var cie10SelectedBadge: some View {
        Text(diagnosisCode)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.mediPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var cie10ResultsList: some View {
        VStack(spacing: 0) {
            ForEach(cie10Results) { code in
                Button {
                    diagnosisCode = code.id
                    if diagnosis.isEmpty {
                        diagnosis = code.description
                    }
                    cie10SearchText = ""
                    showCIE10Results = false
                } label: {
                    cie10ResultRow(code)
                }
            }
        }
        .background(Color.mediSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mediBorder, lineWidth: 0.5))
    }

    private func cie10ResultRow(_ code: CIE10Code) -> some View {
        HStack {
            Text(code.id)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.mediPrimary)
                .frame(width: 60, alignment: .leading)
            Text(code.description)
                .font(.system(size: 13))
                .foregroundStyle(Color.mediText)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var cie10SelectedRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.mediSuccess)
            let matchingCode = CIE10Database.allCodes.first { $0.id == diagnosisCode }
            let label = matchingCode?.displayText ?? diagnosisCode
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.mediText)
            Spacer()
            Button {
                diagnosisCode = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.mediTextMuted)
            }
        }
        .padding(10)
        .background(Color.mediSuccess.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var diagnosisSecondary: some View {
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

    private var estudiosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MediSectionHeader(title: "Estudios", icon: "flask.fill")

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

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MediSectionHeader(title: "Indicaciones y seguimiento", icon: "list.clipboard.fill")

            hcTextArea("Plan de tratamiento", text: $treatmentPlan)
            hcTextArea("Indicaciones al paciente", text: $instructionsText)
            hcTextArea("Seguimiento", text: $followUp, placeholder: "Próximo control, derivaciones pendientes...")
            hcTextArea("Prevención evaluada", text: $prevention, placeholder: "Vacunas, screening, consejos...")
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
    private func hcTextArea(_ label: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.mediTextSoft)
            TextEditor(text: text)
                .font(.system(size: 14))
                .frame(minHeight: 70)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.mediSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    Group {
                        if text.wrappedValue.isEmpty && !placeholder.isEmpty {
                            Text(placeholder)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.mediTextMuted)
                                .padding(.leading, 12)
                                .padding(.top, 16)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mediBorder, lineWidth: 0.5))
        }
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
        recordType = r.recordType ?? "consulta"
        occupation = r.occupation ?? ""
        chiefComplaint = r.chiefComplaint
        diagnosis = r.diagnosis
        presentIllness = r.presentIllness ?? ""
        // El texto guardado va completo al cuadro; los chips se marcan solos según lo que diga
        personalHistoryExtra = r.personalHistory ?? ""
        personalHistory = r.personalHistory ?? ""
        familyHistoryExtra = r.familyHistory ?? ""
        familyHistory = r.familyHistory ?? ""
        currentMedications = r.currentMedications ?? ""
        allergiesText = r.allergies ?? ""
        habits = r.habits ?? ""

        // Parse revisión por sistemas checkboxes
        let (parsedRevisionItems, parsedRevisionNotes, parsedOtherSymptoms) = parseCheckboxes(
            r.systemsReview ?? "",
            allItems: RevisionSistemasData.items.map { ($0.id, $0.label) }
        )
        selectedRevisionItems = parsedRevisionItems
        revisionNotes = parsedRevisionNotes
        systemsReview = r.systemsReview ?? ""
        otherSymptoms = parsedOtherSymptoms.isEmpty ? (r.otherSymptoms ?? "") : parsedOtherSymptoms

        // Parse examen físico checkboxes
        let (parsedExamenItems, parsedExamenNotes, _) = parseCheckboxes(
            r.physicalExam ?? "",
            allItems: ExamenFisicoData.items.map { ($0.id, $0.label) }
        )
        selectedExamenItems = parsedExamenItems
        examenNotes = parsedExamenNotes
        physicalExam = r.physicalExam ?? ""

        findings = r.findings ?? ""
        diagnosisCode = r.diagnosisCode ?? ""
        treatmentPlan = r.treatmentPlan ?? ""
        instructionsText = r.instructions ?? ""
        followUp = r.followUp ?? ""
        prevention = r.prevention ?? ""
        privateNotes = r.privateNotes ?? ""

        if let vs = r.vitalSigns {
            bloodPressure = vs.bloodPressure ?? ""
            heartRate = vs.heartRate.map { "\($0)" } ?? ""
            temperature = vs.temperature.map { String(format: "%.1f", $0) } ?? ""
            respiratoryRate = vs.respiratoryRate.map { "\($0)" } ?? ""
            spO2 = vs.spO2.map { "\($0)" } ?? ""
            weight = vs.weight.map { String(format: "%.1f", $0) } ?? ""
            height = vs.height.map { String(format: "%.0f", $0) } ?? ""
            waistCircumference = vs.waistCircumference.map { String(format: "%.0f", $0) } ?? ""
            shoulderWidth = vs.shoulderWidth.map { String(format: "%.0f", $0) } ?? ""
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
            height: Double(height),
            waistCircumference: Double(waistCircumference),
            shoulderWidth: Double(shoulderWidth)
        )

        let hasVitals = vitals.bloodPressure != nil || vitals.heartRate != nil || vitals.temperature != nil
            || vitals.respiratoryRate != nil || vitals.spO2 != nil || vitals.weight != nil || vitals.height != nil
            || vitals.waistCircumference != nil || vitals.shoulderWidth != nil

        let secondaryList: [SecondaryDiagnosisPayload]? = {
            let lines = secondaryDx.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard !lines.isEmpty else { return nil }
            return lines.map { SecondaryDiagnosisPayload(diagnosis: $0, code: nil) }
        }()

        // Antecedentes: el cuadro de texto ya incluye lo elegido con los chips
        let combinedPersonalHistory = AntecedentesTexto.limpio(personalHistoryExtra)
        let combinedFamilyHistory = AntecedentesTexto.limpio(familyHistoryExtra)

        // Combine revisión por sistemas checkboxes into text
        let combinedSystemsReview = combineCheckboxes(
            selected: selectedRevisionItems,
            notes: revisionNotes,
            allItems: RevisionSistemasData.items.map { ($0.id, $0.label) },
            extraText: otherSymptoms
        )

        // Combine examen físico checkboxes into text
        let combinedPhysicalExam = combineCheckboxes(
            selected: selectedExamenItems,
            notes: examenNotes,
            allItems: ExamenFisicoData.items.map { ($0.id, $0.label) },
            extraText: physicalExam
        )

        let payload = CreateRecordPayload(
            patientId: patientId,
            appointmentId: nil,
            recordType: recordType,
            chiefComplaint: chiefComplaint,
            presentIllness: presentIllness.isEmpty ? nil : presentIllness,
            personalHistory: combinedPersonalHistory,
            familyHistory: combinedFamilyHistory,
            currentMedications: currentMedications.isEmpty ? nil : currentMedications,
            allergies: allergiesText.isEmpty ? nil : allergiesText,
            habits: habits.isEmpty ? nil : habits,
            systemsReview: combinedSystemsReview,
            otherSymptoms: otherSymptoms.isEmpty ? nil : otherSymptoms,
            vitalSigns: hasVitals ? vitals : nil,
            physicalExam: combinedPhysicalExam,
            findings: findings.isEmpty ? nil : findings,
            diagnosis: diagnosis,
            diagnosisCode: diagnosisCode.isEmpty ? nil : diagnosisCode,
            secondaryDiagnoses: secondaryList,
            treatmentPlan: treatmentPlan.isEmpty ? nil : treatmentPlan,
            instructions: instructionsText.isEmpty ? nil : instructionsText,
            labOrders: splitComma(labOrders),
            imagingOrders: splitComma(imagingOrders),
            referrals: splitComma(referrals),
            followUp: followUp.isEmpty ? nil : followUp,
            prevention: prevention.isEmpty ? nil : prevention,
            occupation: occupation.isEmpty ? nil : occupation,
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

    // MARK: - Antecedentes Helpers

    private func combineAntecedentes(chips: Set<String>, extra: String) -> String? {
        var parts: [String] = []
        let orderedChips = chips.sorted()
        if !orderedChips.isEmpty {
            parts.append(orderedChips.joined(separator: ", "))
        }
        let trimmed = extra.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            parts.append(trimmed)
        }
        let result = parts.joined(separator: ". ")
        return result.isEmpty ? nil : result
    }

    // MARK: - Checkbox Helpers (Examen / Revisión)

    private func combineCheckboxes(
        selected: Set<String>,
        notes: [String: String],
        allItems: [(id: String, label: String)],
        extraText: String
    ) -> String? {
        var parts: [String] = []
        for item in allItems where selected.contains(item.id) {
            let note = notes[item.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if note.isEmpty {
                parts.append("[\(item.label)]: evaluado")
            } else {
                parts.append("[\(item.label)]: \(note)")
            }
        }
        let trimmedExtra = extraText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedExtra.isEmpty {
            parts.append(trimmedExtra)
        }
        let result = parts.joined(separator: "; ")
        return result.isEmpty ? nil : result
    }

    private func parseCheckboxes(
        _ text: String,
        allItems: [(id: String, label: String)]
    ) -> (Set<String>, [String: String], String) {
        guard !text.isEmpty else { return ([], [:], "") }
        var found: Set<String> = []
        var notes: [String: String] = [:]
        var remaining = text

        for item in allItems {
            let pattern = "[\(item.label)]:"
            if let range = remaining.range(of: pattern, options: .caseInsensitive) {
                found.insert(item.id)
                // Extract note after the label until next "[" or ";"
                let afterLabel = remaining[range.upperBound...]
                let noteEnd = afterLabel.firstIndex(where: { $0 == ";" }) ?? afterLabel.endIndex
                let note = String(afterLabel[..<noteEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
                if note != "evaluado" && !note.isEmpty {
                    notes[item.id] = note
                }
                // Remove this segment from remaining
                let segEnd = noteEnd < afterLabel.endIndex
                    ? remaining.index(after: noteEnd) : noteEnd
                remaining.removeSubrange(range.lowerBound..<segEnd)
            }
        }

        remaining = remaining
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ";,")))
        return (found, notes, remaining)
    }

    private func parseAntecedentes(_ text: String, knownConditions: [String]) -> (Set<String>, String) {
        guard !text.isEmpty else { return ([], "") }
        var found: Set<String> = []
        let lower = text.lowercased()
        for condition in knownConditions {
            if lower.contains(condition.lowercased()) {
                found.insert(condition)
            }
        }
        var remaining = text
        for condition in found {
            remaining = remaining.replacingOccurrences(
                of: condition, with: "", options: .caseInsensitive
            )
        }
        remaining = remaining.replacingOccurrences(of: ", ,", with: ",")
            .replacingOccurrences(of: ". .", with: ".")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",.")))
        while remaining.contains("  ") {
            remaining = remaining.replacingOccurrences(of: "  ", with: " ")
        }
        return (found, remaining)
    }
}

// MARK: - Antecedentes: chips ↔ texto

/// Los chips de antecedentes escriben en el cuadro de texto, que es lo que se guarda.
enum AntecedentesTexto {
    private static func rango(_ condicion: String, en texto: String) -> Range<String.Index>? {
        // Coincide la palabra completa, sin importar mayúsculas ni tildes
        let patron = "(?<![\\p{L}])" + NSRegularExpression.escapedPattern(for: condicion) + "(?![\\p{L}])"
        return texto.range(of: patron, options: [.regularExpression, .caseInsensitive, .diacriticInsensitive])
    }

    static func contiene(_ condicion: String, en texto: String) -> Bool {
        rango(condicion, en: texto) != nil
    }

    static func alternar(_ condicion: String, en texto: String) -> String {
        if let r = rango(condicion, en: texto) {
            var t = texto
            t.removeSubrange(r)
            return ordenar(t)
        }
        let base = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty { return condicion }
        let separador = base.hasSuffix(",") || base.hasSuffix(".") || base.hasSuffix(";") ? " " : ", "
        return base + separador + condicion
    }

    /// Quita comas o espacios que quedan sueltos al borrar un antecedente.
    static func ordenar(_ texto: String) -> String {
        var t = texto
        while t.contains(", ,") { t = t.replacingOccurrences(of: ", ,", with: ",") }
        while t.contains(",,") { t = t.replacingOccurrences(of: ",,", with: ",") }
        while t.contains("  ") { t = t.replacingOccurrences(of: "  ", with: " ") }
        t = t.replacingOccurrences(of: " ,", with: ",").replacingOccurrences(of: ",.", with: ".")
        return t.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;")))
    }

    static func limpio(_ texto: String) -> String? {
        let t = ordenar(texto)
        return t.isEmpty ? nil : t
    }
}

// MARK: - ChipToggle

struct ChipToggle: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : Color.mediText)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.mediPrimary : Color.mediSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color.mediBorder, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ChipFlowLayout (wrapping horizontal layout for chips)

struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height),
            subviews: subviews
        )
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews)
        -> (size: CGSize, positions: [CGPoint])
    {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}
