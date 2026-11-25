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
                        .listRowBackground(Color.mediSurface)
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
    @State private var editarPaciente = false
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

                        if let phone = patient.phone, !phone.isEmpty {
                            HStack(spacing: 10) {
                                Link(destination: URL(string: "tel:\(phone)")!) {
                                    Label("Llamar", systemImage: "phone.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.mediSuccess)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.mediSuccess.opacity(0.1))
                                        .clipShape(Capsule())
                                }

                                Button {
                                    WhatsAppHelper.open(
                                        phone: phone,
                                        message: "Hola \(patient.fullName), nos comunicamos desde el consultorio. TusRecetasMed"
                                    )
                                } label: {
                                    Label("WhatsApp", systemImage: "message.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color(hex: "25D366"))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color(hex: "25D366").opacity(0.1))
                                        .clipShape(Capsule())
                                }

                                Spacer()
                            }
                            .padding(.top, 4)
                        }
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
                    
                    // Tabs: Timeline / Turnos / Recetas / Registros
                    HStack(spacing: 0) {
                        HCTab(title: "Timeline", isActive: activeTab == 0) { activeTab = 0 }
                        HCTab(title: "Turnos", isActive: activeTab == 1) { activeTab = 1 }
                        HCTab(title: "Recetas", isActive: activeTab == 2) { activeTab = 2 }
                        HCTab(title: "HC", isActive: activeTab == 3) { activeTab = 3 }
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
                        case 3:
                            let pid = patient.remoteId?.uuidString ?? patient.id.uuidString
                            MedicalRecordsListView(patientId: pid)
                        default: EmptyView()
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Historia clínica")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editarPaciente) { NewPatientView(editar: patient) }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Editar") { editarPaciente = true }
                    .foregroundStyle(Color.mediTeal)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await downloadHCPdf() }
                } label: {
                    Label("Exportar HC", systemImage: "arrow.down.doc.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.mediTeal)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = pdfShareItem {
                ShareSheet(items: [url])
            }
        }
        .task { await loadHistory() }
    }

    @State private var isDownloadingPdf = false
    @State private var pdfShareItem: URL?
    @State private var showShareSheet = false

    private func downloadHCPdf() async {
        guard !isDownloadingPdf else { return }
        await MainActor.run { isDownloadingPdf = true }

        let patientId = patient.remoteId?.uuidString ?? patient.id.uuidString
        do {
            let data = try await APIClient.shared.download("/api/v1/medical-records/patient/\(patientId)/pdf")
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("HC_\(patient.fullName.replacingOccurrences(of: " ", with: "_")).pdf")
            try data.write(to: url)
            await MainActor.run {
                isDownloadingPdf = false
                pdfShareItem = url
                showShareSheet = true
            }
        } catch {
            await MainActor.run {
                isDownloadingPdf = false
            }
            print("❌ Error downloading HC PDF: \(error)")
        }
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
    
    // CodingKeys removed — APIClient.decoder uses .convertFromSnakeCase

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
    
    // CodingKeys removed — APIClient.decoder uses .convertFromSnakeCase

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
    
    // CodingKeys removed — APIClient.decoder uses .convertFromSnakeCase
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
        .buttonStyle(MediPressStyle())
    }
}


struct NewPatientView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Si viene un paciente, el formulario edita sus datos.
    private let editar: LocalPatient?

    @State private var firstName: String
    @State private var lastName: String
    @State private var dni: String
    @State private var cuil: String
    @State private var sexo: String
    @State private var phone: String
    @State private var email: String
    @State private var tieneNacimiento: Bool
    @State private var dateOfBirth: Date
    @State private var insuranceProvider: String
    @State private var insuranceNumber: String
    @State private var allergiesText: String
    @State private var conditionsText: String

    @State private var intento = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var errorHaptico = 0

    init(editar: LocalPatient? = nil) {
        self.editar = editar
        _firstName = State(initialValue: editar?.firstName ?? "")
        _lastName = State(initialValue: editar?.lastName ?? "")
        _dni = State(initialValue: editar?.dni ?? "")
        _cuil = State(initialValue: editar?.cuil.map { MediValida.formatoCuil($0) } ?? "")
        _sexo = State(initialValue: editar?.gender ?? "not_specified")
        _phone = State(initialValue: editar?.phone ?? "")
        _email = State(initialValue: editar?.email ?? "")
        _tieneNacimiento = State(initialValue: editar?.dateOfBirth != nil)
        _dateOfBirth = State(initialValue: editar?.dateOfBirth ?? (Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()))
        _insuranceProvider = State(initialValue: editar?.insuranceProvider ?? "")
        _insuranceNumber = State(initialValue: editar?.insuranceNumber ?? "")
        _allergiesText = State(initialValue: editar?.allergies.joined(separator: ", ") ?? "")
        _conditionsText = State(initialValue: editar?.chronicConditions.joined(separator: ", ") ?? "")
    }

    // Errores por campo: se muestran apenas se escribe algo, o todos al intentar guardar.
    private func ver(_ e: String?, _ valor: String) -> String? { (intento || !valor.isEmpty) ? e : nil }
    private var eNombre: String? { ver(MediValida.nombre(firstName, campo: "nombre"), firstName) }
    private var eApellido: String? { ver(MediValida.nombre(lastName, campo: "apellido"), lastName) }
    private var eDni: String? { ver(MediValida.dni(dni), dni) }
    private var eCuil: String? { ver(MediValida.cuil(cuil, dni: dni), cuil) }
    private var eTel: String? { ver(MediValida.telefono(phone), phone) }
    private var eMail: String? { ver(MediValida.email(email), email) }
    private var eNac: String? { tieneNacimiento ? MediValida.nacimiento(dateOfBirth) : nil }

    private var hayErrores: Bool {
        MediValida.nombre(firstName, campo: "nombre") != nil || MediValida.nombre(lastName, campo: "apellido") != nil
            || MediValida.dni(dni) != nil || MediValida.cuil(cuil, dni: dni) != nil
            || MediValida.telefono(phone) != nil || MediValida.email(email) != nil || eNac != nil
    }

    /// CUIL a enviar: el cargado o el calculado con DNI + sexo.
    private var cuilFinal: String? {
        let d = MediValida.digitos(cuil)
        if !d.isEmpty { return d }
        return MediValida.cuilDesdeDni(dni, sexo: sexo)
    }

    private var avisoReceta: String? {
        if MediValida.digitos(dni).isEmpty { return "Sin DNI no vas a poder hacerle recetas electrónicas." }
        if cuilFinal == nil { return "Cargá el CUIL o el sexo para poder hacerle recetas electrónicas." }
        return nil
    }

    @ViewBuilder
    private func campo(_ titulo: String, _ texto: Binding<String>, error: String?, teclado: UIKeyboardType = .default, mayus: TextInputAutocapitalization = .words) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(titulo, text: texto)
                .keyboardType(teclado)
                .textInputAutocapitalization(mayus)
                .autocorrectionDisabled(teclado != .default)
                .foregroundStyle(error == nil ? Color.mediText : Color.mediDanger)
            MediFieldError(mensaje: error)
        }
        .animation(.snappy, value: error)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                Form {
                    Section {
                        campo("Nombre *", $firstName, error: eNombre)
                        campo("Apellido *", $lastName, error: eApellido)
                        campo("DNI", $dni, error: eDni, teclado: .numberPad, mayus: .never)
                        Picker("Sexo (para el CUIL)", selection: $sexo) {
                            Text("Sin indicar").tag("not_specified")
                            Text("Femenino").tag("female")
                            Text("Masculino").tag("male")
                            Text("X").tag("other")
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            campo("CUIL (XX-XXXXXXXX-X)", $cuil, error: eCuil, teclado: .numberPad, mayus: .never)
                            if MediValida.digitos(cuil).isEmpty, let c = MediValida.cuilDesdeDni(dni, sexo: sexo), MediValida.dni(dni) == nil {
                                Button {
                                    cuil = MediValida.formatoCuil(c)
                                } label: {
                                    Label("Usar \(MediValida.formatoCuil(c)) (calculado con DNI y sexo)", systemImage: "wand.and.stars")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        campo("Celular (WhatsApp)", $phone, error: eTel, teclado: .phonePad, mayus: .never)
                        campo("Email", $email, error: eMail, teclado: .emailAddress, mayus: .never)
                        if tieneNacimiento {
                            VStack(alignment: .leading, spacing: 4) {
                                DatePicker("Nacimiento", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                                MediFieldError(mensaje: eNac)
                            }
                        } else {
                            Button { tieneNacimiento = true } label: {
                                Label("Agregar fecha de nacimiento", systemImage: "calendar.badge.plus")
                            }
                        }
                    } header: {
                        Label("Datos personales", systemImage: "person.fill")
                    } footer: {
                        if let a = avisoReceta { Text(a).foregroundStyle(Color.mediWarning) }
                    }

                    Section {
                        TextField("Obra social / Prepaga", text: $insuranceProvider)
                        TextField("Nro. de afiliado", text: $insuranceNumber)
                            .textInputAutocapitalization(.never)
                    } header: {
                        Label("Obra social", systemImage: "cross.case.fill")
                    }

                    Section {
                        TextField("Alergias (separar con coma)", text: $allergiesText)
                        TextField("Condiciones crónicas (separar con coma)", text: $conditionsText)
                    } header: {
                        Label("Datos clínicos", systemImage: "heart.text.clipboard")
                    }

                    Section {
                        Button { guardar() } label: {
                            HStack {
                                if isSaving { ProgressView() } else { Image(systemName: editar == nil ? "person.badge.plus" : "checkmark") }
                                Text(editar == nil ? "Guardar paciente" : "Guardar cambios")
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(Color.mediPrimary)
                        }
                        .disabled(isSaving)
                    } footer: {
                        if let e = saveError {
                            Label(e, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Color.mediDanger)
                        } else if intento && hayErrores {
                            Text("Corregí los campos marcados en rojo.").foregroundStyle(Color.mediDanger)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(editar == nil ? "Nuevo paciente" : "Editar paciente")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.error, trigger: errorHaptico)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private func guardar() {
        withAnimation(.snappy) { intento = true }
        guard !hayErrores else { errorHaptico += 1; return }
        isSaving = true
        saveError = nil

        struct PatientReq: Encodable {
            let firstName: String
            let lastName: String
            let dni: String?
            let cuil: String?
            let gender: String?
            let phone: String?
            let email: String?
            let dateOfBirth: String?
            let insuranceProvider: String?
            let insuranceNumber: String?
            let allergies: [String]?
            let chronicConditions: [String]?
        }
        struct PatientResp: Decodable { let id: String }

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        func n(_ s: String) -> String? { let t = MediValida.limpio(s); return t.isEmpty ? nil : t }
        func lista(_ s: String) -> [String] { s.split(separator: ",").map { MediValida.limpio(String($0)) }.filter { !$0.isEmpty } }

        let dniD = MediValida.digitos(dni)
        let req = PatientReq(
            firstName: MediValida.limpio(firstName), lastName: MediValida.limpio(lastName),
            dni: dniD.isEmpty ? nil : dniD,
            cuil: cuilFinal,
            gender: sexo == "not_specified" ? nil : sexo,
            phone: n(phone), email: n(email)?.lowercased(),
            dateOfBirth: tieneNacimiento ? f.string(from: dateOfBirth) : nil,
            insuranceProvider: n(insuranceProvider), insuranceNumber: n(insuranceNumber),
            allergies: lista(allergiesText), chronicConditions: lista(conditionsText))

        Task {
            do {
                let remoteId: String
                if let p = editar, let rid = p.remoteId {
                    let _: PatientResp = try await APIClient.shared.put("/api/v1/patients/\(rid.uuidString.lowercased())", body: req)
                    remoteId = rid.uuidString
                } else {
                    let r: PatientResp = try await APIClient.shared.post("/api/v1/patients", body: req)
                    remoteId = r.id
                }
                await MainActor.run {
                    let patient = editar ?? LocalPatient(doctorId: UUID(), firstName: req.firstName, lastName: req.lastName)
                    patient.remoteId = UUID(uuidString: remoteId)
                    patient.firstName = req.firstName
                    patient.lastName = req.lastName
                    patient.dni = req.dni
                    patient.cuil = req.cuil
                    patient.gender = sexo
                    patient.phone = req.phone
                    patient.email = req.email
                    patient.dateOfBirth = tieneNacimiento ? dateOfBirth : nil
                    patient.insuranceProvider = req.insuranceProvider
                    patient.insuranceNumber = req.insuranceNumber
                    patient.allergies = req.allergies ?? []
                    patient.chronicConditions = req.chronicConditions ?? []
                    patient.syncStatus = .synced
                    patient.updatedAt = Date()
                    if editar == nil { modelContext.insert(patient) }
                    try? modelContext.save()
                    isSaving = false
                    MediFeedback.exito(editar == nil ? "Paciente guardado" : "Datos actualizados", patient.fullName)
                    dismiss()
                }
            } catch {
                if (error as? APIError)?.requiresLogin == true { await MainActor.run { isSaving = false }; return }
                await MainActor.run {
                    saveError = (error as? LocalizedError)?.errorDescription ?? "No se pudo guardar. Intentá de nuevo."
                    isSaving = false
                    errorHaptico += 1
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
