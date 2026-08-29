import SwiftUI
import SwiftData

struct PatientsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalPatient.lastName) private var patients: [LocalPatient]
    @State private var searchText = ""
    @State private var showNewPatient = false
    
    var filteredPatients: [LocalPatient] {
        if searchText.isEmpty { return patients }
        return patients.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText) ||
            ($0.dni ?? "").contains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                List {
                    ForEach(filteredPatients) { patient in
                        NavigationLink {
                            PatientDetailView(patient: patient)
                        } label: {
                            HStack(spacing: 12) {
                                MediAvatar(name: patient.fullName, size: 44)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(patient.fullName)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Color.mediText)
                                    HStack(spacing: 4) {
                                        Image(systemName: "heart.text.clipboard")
                                            .font(.caption2)
                                        Text(patient.chronicConditions.joined(separator: " · "))
                                            .lineLimit(1)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(Color.mediTextSoft)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    if let age = patient.age {
                                        Text("\(age) años")
                                            .font(.mediCaption(15))
                                            .foregroundStyle(Color.mediPrimary)
                                    }
                                    Text(patient.insuranceProvider ?? "")
                                        .font(.caption2)
                                        .foregroundStyle(Color.mediTextMuted)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Buscar por nombre o DNI")
            }
            .navigationTitle("Pacientes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewPatient = true } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(Color.mediPrimary)
                    }
                }
            }
            .overlay {
                if patients.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.badge.gearshape")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.mediPrimary.opacity(0.4))
                        Text("Sin pacientes")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(Color.mediText)
                        Text("Agregá tu primer paciente")
                            .font(.subheadline)
                            .foregroundStyle(Color.mediTextSoft)
                        Button("Agregar paciente") { showNewPatient = true }
                            .buttonStyle(MediButtonStyle())
                            .frame(width: 200)
                    }
                }
            }
            .sheet(isPresented: $showNewPatient) {
                NewPatientView()
            }
        }
    }
}

struct PatientDetailView: View {
    let patient: LocalPatient
    @State private var history: PatientHistory?
    @State private var isLoading = true
    @State private var activeTab = 0
    
    var body: some View {
        ZStack {
            MediBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    // Header
                    VStack(spacing: 10) {
                        MediAvatar(name: patient.fullName, size: 64)
                        Text(patient.fullName)
                            .font(.mediTitle(20))
                            .foregroundStyle(Color.mediText)
                        if let age = patient.age {
                            Text("\(age) años · DNI \(patient.dni ?? "—")")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.mediTextSoft)
                        }
                        HStack(spacing: 12) {
                            if let ins = patient.insuranceProvider {
                                MediBadge(ins, color: .mediTeal)
                            }
                            if let num = patient.insuranceNumber, !num.isEmpty {
                                Text("# \(num)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.mediTextMuted)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .mediElevated(padding: 20)
                    
                    // Stats
                    if let h = history {
                        HStack(spacing: 8) {
                            HCStat(value: "\(h.stats.totalAppointments)", label: "Consultas", color: .mediTeal)
                            HCStat(value: "\(h.stats.totalPrescriptions)", label: "Recetas", color: .mediSuccess)
                            HCStat(value: "\(h.stats.totalRecords)", label: "Registros", color: .mediWarning)
                        }
                    }
                    
                    // Contact + medical info
                    VStack(alignment: .leading, spacing: 10) {
                        MediSectionHeader(title: "Datos", icon: "person.text.rectangle")
                        MediInfoRow(icon: "phone.fill", label: "Teléfono", value: patient.phone ?? "—")
                        MediInfoRow(icon: "envelope.fill", label: "Email", value: patient.email ?? "—")
                    }
                    .mediElevated()
                    
                    if !patient.allergies.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            MediSectionHeader(title: "Alergias", icon: "exclamationmark.triangle")
                            FlowLayout(items: patient.allergies) { a in MediBadge(a, color: .mediDanger) }
                        }
                        .mediElevated()
                    }
                    
                    if !patient.chronicConditions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            MediSectionHeader(title: "Condiciones crónicas", icon: "heart.text.clipboard")
                            FlowLayout(items: patient.chronicConditions) { c in MediBadge(c, color: .mediWarning) }
                        }
                        .mediElevated()
                    }
                    
                    // Tabs: Timeline / Turnos / Recetas
                    HStack(spacing: 0) {
                        HCTab(title: "Timeline", isActive: activeTab == 0) { activeTab = 0 }
                        HCTab(title: "Turnos", isActive: activeTab == 1) { activeTab = 1 }
                        HCTab(title: "Recetas", isActive: activeTab == 2) { activeTab = 2 }
                    }
                    .background(Color.mediSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mediBorder, lineWidth: 0.5))
                    
                    if isLoading {
                        ProgressView().tint(.mediTeal).padding(30)
                    } else if let h = history {
                        switch activeTab {
                        case 0: timelineView(h.timeline)
                        case 1: appointmentsView(h.appointments)
                        case 2: prescriptionsView(h.prescriptions)
                        default: EmptyView()
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Historia clínica")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadHistory() }
    }
    
    // MARK: - Timeline
    
    @ViewBuilder
    private func timelineView(_ items: [TimelineItem]) -> some View {
        if items.isEmpty {
            emptyState("Sin registros", icon: "clock")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 12) {
                        // Timeline line + dot
                        VStack(spacing: 0) {
                            Circle()
                                .fill(item.typeColor)
                                .frame(width: 10, height: 10)
                                .padding(.top, 6)
                            if idx < items.count - 1 {
                                Rectangle()
                                    .fill(Color.mediBorder)
                                    .frame(width: 1)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        .frame(width: 10)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.mediText)
                                Spacer()
                                Text(item.dateFormatted)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.mediTextMuted)
                            }
                            if let sub = item.subtitle, !sub.isEmpty {
                                Text(sub)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.mediTextSoft)
                                    .lineLimit(2)
                            }
                            if let status = item.status {
                                MediBadge(MediStatus.label(for: status), color: MediStatus.color(for: status))
                            }
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
            .mediElevated()
        }
    }
    
    // MARK: - Appointments
    
    @ViewBuilder
    private func appointmentsView(_ appts: [HCAppointment]) -> some View {
        if appts.isEmpty {
            emptyState("Sin turnos", icon: "calendar")
        } else {
            VStack(spacing: 8) {
                ForEach(appts) { a in
                    HStack(spacing: 12) {
                        VStack(spacing: 2) {
                            Text(a.dayFormatted)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.mediText)
                            Text(a.monthFormatted)
                                .font(.system(size: 10))
                                .foregroundStyle(Color.mediTextMuted)
                        }
                        .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(a.startTime?.prefix(5) ?? "")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.mediText)
                            Text(a.doctorName ?? "")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.mediTextSoft)
                            if let r = a.reason, !r.isEmpty {
                                Text(r)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.mediTextMuted)
                            }
                        }
                        
                        Spacer()
                        MediBadge(MediStatus.label(for: a.status), color: MediStatus.color(for: a.status))
                    }
                    .padding(12)
                    .background(Color.mediSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mediBorder, lineWidth: 0.5))
                }
            }
        }
    }
    
    // MARK: - Prescriptions
    
    @ViewBuilder
    private func prescriptionsView(_ rxs: [HCPrescription]) -> some View {
        if rxs.isEmpty {
            emptyState("Sin recetas", icon: "pills")
        } else {
            VStack(spacing: 8) {
                ForEach(rxs) { rx in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(rx.diagnosis ?? "Sin diagnóstico")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.mediText)
                            Spacer()
                            MediBadge(MediStatus.label(for: rx.status), color: MediStatus.color(for: rx.status))
                        }
                        
                        if let items = rx.items {
                            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                                HStack(spacing: 6) {
                                    Image(systemName: "pills.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.mediTeal)
                                    Text("\(item.medicationName ?? "") — \(item.dosage ?? "") \(item.frequency ?? "")")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.mediTextSoft)
                                }
                            }
                        }
                        
                        HStack {
                            Text(rx.dateFormatted)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.mediTextMuted)
                            Spacer()
                            Text(rx.doctorName ?? "")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.mediTextMuted)
                        }
                    }
                    .mediElevated()
                }
            }
        }
    }
    
    private func emptyState(_ text: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 28)).foregroundStyle(Color.mediTextMuted)
            Text(text).font(.system(size: 13)).foregroundStyle(Color.mediTextSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
    
    // MARK: - Load
    
    private func loadHistory() async {
        let patientId = patient.remoteId?.uuidString ?? patient.id.uuidString
        do {
            let h: PatientHistory = try await APIClient.shared.get("/api/v1/patients/\(patientId)/history")
            await MainActor.run { history = h; isLoading = false }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - History Models

struct PatientHistory: Decodable {
    let stats: HCStats
    let timeline: [TimelineItem]
    let appointments: [HCAppointment]
    let prescriptions: [HCPrescription]
}

struct HCStats: Decodable {
    let totalAppointments: Int
    let completedAppointments: Int
    let totalPrescriptions: Int
    let activePrescriptions: Int
    let totalRecords: Int
    let firstVisit: String?
    let lastVisit: String?
}

struct TimelineItem: Decodable {
    let type: String
    let date: String
    let title: String
    let subtitle: String?
    let status: String?
    
    var typeColor: Color {
        switch type {
        case "appointment": return .mediTeal
        case "prescription": return .mediSuccess
        case "record": return .mediWarning
        default: return .mediTextMuted
        }
    }
    
    var dateFormatted: String {
        let parts = date.prefix(10).split(separator: "-")
        guard parts.count >= 3 else { return String(date.prefix(10)) }
        return "\(parts[2])/\(parts[1])"
    }
}

struct HCAppointment: Decodable, Identifiable {
    let id: String
    let date: String
    let startTime: String?
    let status: String
    let reason: String?
    let doctorName: String?
    
    enum CodingKeys: String, CodingKey {
        case id, date, status, reason
        case startTime = "start_time"
        case doctorName = "doctor_name"
    }
    
    var dayFormatted: String { String(date.prefix(10).suffix(2)) }
    var monthFormatted: String {
        let months = ["","Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Sep","Oct","Nov","Dic"]
        let m = Int(date.prefix(7).suffix(2)) ?? 0
        return months[min(m, 12)]
    }
}

struct HCPrescription: Decodable, Identifiable {
    let id: String
    let diagnosis: String?
    let status: String
    let issuedAt: String?
    let doctorName: String?
    let items: [HCPrescriptionItem]?
    
    enum CodingKeys: String, CodingKey {
        case id, diagnosis, status, items
        case issuedAt = "issued_at"
        case doctorName = "doctor_name"
    }
    
    var dateFormatted: String {
        guard let d = issuedAt else { return "—" }
        let parts = d.prefix(10).split(separator: "-")
        guard parts.count >= 3 else { return String(d.prefix(10)) }
        return "\(parts[2])/\(parts[1])/\(parts[0])"
    }
}

struct HCPrescriptionItem: Decodable {
    let medicationName: String?
    let dosage: String?
    let frequency: String?
    let duration: String?
    
    enum CodingKeys: String, CodingKey {
        case dosage, frequency, duration
        case medicationName = "medication_name"
    }
}

// MARK: - UI Components

struct HCStat: View {
    let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .medium)).foregroundStyle(Color.mediText)
            Text(label).font(.system(size: 10)).foregroundStyle(Color.mediTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.12), lineWidth: 0.5))
    }
}

struct HCTab: View {
    let title: String; let isActive: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isActive ? Color.mediTeal : Color.mediTextMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isActive ? Color.mediTealSoft : Color.clear)
        }
        .buttonStyle(.plain)
    }
}


struct NewPatientView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dni = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var dateOfBirth = Date()
    @State private var insuranceProvider = ""
    @State private var insuranceNumber = ""
    @State private var allergiesText = ""
    @State private var conditionsText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                Form {
                    Section {
                        Label("Datos personales", systemImage: "person.fill")
                            .foregroundStyle(Color.mediPrimary)
                    }
                    Section {
                        TextField("Nombre *", text: $firstName)
                        TextField("Apellido *", text: $lastName)
                        TextField("DNI", text: $dni).keyboardType(.numberPad)
                        TextField("Teléfono", text: $phone).keyboardType(.phonePad)
                        TextField("Email", text: $email).keyboardType(.emailAddress).autocapitalization(.none)
                        DatePicker("Nacimiento", selection: $dateOfBirth, displayedComponents: .date)
                    }
                    Section {
                        Label("Obra social", systemImage: "cross.case.fill")
                            .foregroundStyle(Color.mediPrimary)
                    }
                    Section {
                        TextField("Obra social / Prepaga", text: $insuranceProvider)
                        TextField("Nro. de afiliado", text: $insuranceNumber)
                    }
                    Section {
                        Label("Datos clínicos", systemImage: "heart.text.clipboard")
                            .foregroundStyle(Color.mediPrimary)
                    }
                    Section {
                        TextField("Alergias (separar con coma)", text: $allergiesText)
                        TextField("Condiciones crónicas (separar con coma)", text: $conditionsText)
                    }
                    Section {
                        Button { save() } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Guardar paciente")
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(Color.mediPrimary)
                        }
                        .disabled(firstName.isEmpty || lastName.isEmpty)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Nuevo paciente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
    
    @State private var isSaving = false
    @State private var saveError: String?
    
    private func save() {
        guard !firstName.isEmpty, !lastName.isEmpty else { return }
        isSaving = true
        saveError = nil
        
        Task {
            struct CreatePatientReq: Encodable {
                let firstName: String
                let lastName: String
                let dni: String?
                let phone: String?
                let email: String?
                let dateOfBirth: String?
                let insuranceProvider: String?
                let insuranceNumber: String?
                let allergies: [String]?
                let chronicConditions: [String]?
            }
            
            struct CreatePatientResp: Decodable {
                let id: String
                let firstName: String
                let lastName: String
            }
            
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            
            let req = CreatePatientReq(
                firstName: firstName, lastName: lastName,
                dni: dni.isEmpty ? nil : dni,
                phone: phone.isEmpty ? nil : phone,
                email: email.isEmpty ? nil : email,
                dateOfBirth: f.string(from: dateOfBirth),
                insuranceProvider: insuranceProvider.isEmpty ? nil : insuranceProvider,
                insuranceNumber: insuranceNumber.isEmpty ? nil : insuranceNumber,
                allergies: allergiesText.isEmpty ? nil : allergiesText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                chronicConditions: conditionsText.isEmpty ? nil : conditionsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            )
            
            do {
                let resp: CreatePatientResp = try await APIClient.shared.post("/api/v1/patients", body: req)
                
                // Guardar en local como caché con remoteId
                await MainActor.run {
                    let patient = LocalPatient(doctorId: UUID(), firstName: firstName, lastName: lastName)
                    patient.remoteId = UUID(uuidString: resp.id)
                    patient.dni = dni.isEmpty ? nil : dni
                    patient.phone = phone.isEmpty ? nil : phone
                    patient.email = email.isEmpty ? nil : email
                    patient.dateOfBirth = dateOfBirth
                    patient.insuranceProvider = insuranceProvider.isEmpty ? nil : insuranceProvider
                    patient.insuranceNumber = insuranceNumber.isEmpty ? nil : insuranceNumber
                    patient.syncStatus = .synced
                    modelContext.insert(patient)
                    try? modelContext.save()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    saveError = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

struct FlowLayout<T: Hashable, Content: View>: View {
    let items: [T]
    let content: (T) -> Content
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in content(item) }
        }
    }
}
