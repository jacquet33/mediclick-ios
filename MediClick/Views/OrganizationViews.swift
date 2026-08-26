import SwiftUI

// MARK: - API Response Models

struct OrgDetailResponse: Decodable {
    let id: String
    let name: String
    let type: String
    let cuit: String?
    let taxName: String?
    let phone: String?
    let email: String?
    let address: String?
    let city: String?
    let province: String?
    let postalCode: String?
    let defaultSlotDuration: Int?
    let patientCount: Int?
    let doctorCount: Int?
}

struct OrgStatsResponse: Decodable {
    let totalPatients: Int
    let totalDoctors: Int
    let todayAppointments: Int
    let activePrescriptions: Int
    let completedToday: Int
    let unreadMessages: Int
}

struct OrgDoctorResponse: Decodable, Identifiable {
    let id: String
    let doctorId: String
    let fullName: String
    let email: String
    let specialty: String?
    let role: String
    let isOwner: Bool?
}

struct InvitationResponse: Decodable, Identifiable {
    let id: String
    let orgName: String
    let orgType: String
    let invitedByName: String
    let role: String
    let createdAt: Date
}

struct CreateOrgRequest: Encodable {
    let name: String
    let type: String
    var cuit: String?
    var taxName: String?
    var phone: String?
    var email: String?
    var address: String?
    var city: String?
    var province: String?
    var postalCode: String?
    var defaultSlotDuration: Int?
}

struct CreateOrgResponse: Decodable {
    let organization: OrgCreated
    let membership: OrgMembership

    struct OrgCreated: Decodable {
        let id: String
        let name: String
        let type: String
    }
    struct OrgMembership: Decodable {
        let id: String
        let organizationId: String
        let doctorId: String
        let role: String
    }
}

struct InviteRequest: Encodable {
    let email: String
    let role: String
}

struct MessageResponse: Decodable {
    let message: String
}

// MARK: - Organization Detail View

struct OrganizationDetailView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    
    let org: AuthManager.OrgInfo
    
    @State private var detail: OrgDetailResponse?
    @State private var stats: OrgStatsResponse?
    @State private var doctors: [OrgDoctorResponse] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var showInvite = false
    @State private var showEdit = false
    
    private var isOwnerOrAdmin: Bool {
        org.role == "owner" || org.role == "admin"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                if isLoading {
                    ProgressView()
                        .tint(.mediPrimary)
                } else if let error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.mediWarning)
                        Text(error)
                            .font(.mediBody())
                            .foregroundStyle(Color.mediTextSoft)
                            .multilineTextAlignment(.center)
                        Button("Reintentar") { Task { await loadAll() } }
                            .buttonStyle(MediButtonStyle())
                    }
                    .padding(40)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            orgHeader
                            if let stats { statsGrid(stats) }
                            doctorsSection
                            if isOwnerOrAdmin { settingsSection }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle(org.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Color.mediPrimary)
                }
                if isOwnerOrAdmin {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showEdit = true } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(Color.mediPrimary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showInvite) {
                InviteDoctorView(orgId: org.id) {
                    Task { await loadDoctors() }
                }
            }
            .sheet(isPresented: $showEdit) {
                if let detail {
                    EditOrganizationView(orgId: org.id, current: detail) {
                        Task { await loadDetail() }
                    }
                }
            }
            .task { await loadAll() }
        }
    }
    
    // MARK: - Subviews
    
    private var orgHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient.medi(orgGradient(org.type)))
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(LinearGradient.mediShine)
                    .frame(width: 72, height: 72)
                Image(systemName: orgIcon(org.type))
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
            }
            .shadow(color: .mediPrimary.opacity(0.25), radius: 12, y: 4)
            
            VStack(spacing: 4) {
                Text(detail?.name ?? org.name)
                    .font(.mediTitle(22))
                    .foregroundStyle(Color.mediText)
                Text(orgTypeLabel(org.type))
                    .font(.subheadline)
                    .foregroundStyle(Color.mediTextSoft)
            }
            
            if let d = detail {
                VStack(spacing: 6) {
                    if let phone = d.phone, !phone.isEmpty {
                        Label(phone, systemImage: "phone.fill")
                    }
                    if let email = d.email, !email.isEmpty {
                        Label(email, systemImage: "envelope.fill")
                    }
                    if let addr = d.address, !addr.isEmpty {
                        let full = [addr, d.city, d.province].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
                        Label(full, systemImage: "mappin.and.ellipse")
                    }
                    if let cuit = d.cuit, !cuit.isEmpty {
                        Label("CUIT: \(cuit)", systemImage: "doc.text")
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.mediTextSoft)
            }
        }
        .frame(maxWidth: .infinity)
        .mediElevated(padding: 24)
    }
    
    private func statsGrid(_ s: OrgStatsResponse) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(icon: "person.2.fill", value: "\(s.totalPatients)", label: "Pacientes", color: .mediCyan)
            StatCard(icon: "stethoscope", value: "\(s.totalDoctors)", label: "Médicos", color: .mediSky)
            StatCard(icon: "calendar", value: "\(s.todayAppointments)", label: "Turnos hoy", color: .mediPrimary)
            StatCard(icon: "checkmark.circle.fill", value: "\(s.completedToday)", label: "Atendidos", color: .mediSuccess)
        }
    }
    
    private var doctorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MediSectionHeader(title: "Equipo médico", icon: "person.3.fill")
            
            ForEach(doctors) { doc in
                HStack(spacing: 12) {
                    MediAvatar(name: doc.fullName, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(doc.fullName)
                            .font(.mediCaption(15))
                            .foregroundStyle(Color.mediText)
                        Text(doc.specialty ?? "Médico")
                            .font(.caption)
                            .foregroundStyle(Color.mediTextSoft)
                    }
                    Spacer()
                    MediBadge(roleLabel(doc.role), color: doc.role == "owner" ? .mediPrimary : .mediSuccess)
                }
                .padding(.vertical, 4)
            }
            
            if doctors.isEmpty {
                Text("Solo vos por ahora")
                    .font(.caption)
                    .foregroundStyle(Color.mediTextMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
            
            if isOwnerOrAdmin {
                Button { showInvite = true } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Invitar médico")
                        Spacer()
                    }
                    .font(.mediCaption(15))
                    .foregroundStyle(Color.mediPrimary)
                    .padding(12)
                }
            }
        }
        .mediElevated()
    }
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            MediSectionHeader(title: "Configuración", icon: "gearshape.fill")
            
            SettingRow(icon: "clock.fill", title: "Duración turnos: \(detail?.defaultSlotDuration ?? 30) min", color: .mediCyan) { }
        }
        .mediElevated()
    }
    
    // MARK: - Data
    
    private func loadAll() async {
        isLoading = true
        error = nil
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadDetail() }
            group.addTask { await loadStats() }
            group.addTask { await loadDoctors() }
        }
        isLoading = false
    }
    
    private func loadDetail() async {
        do {
            let d: OrgDetailResponse = try await APIClient.shared.get("/api/v1/organizations/\(org.id)")
            await MainActor.run { detail = d }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
    
    private func loadStats() async {
        do {
            let s: OrgStatsResponse = try await APIClient.shared.get("/api/v1/organizations/\(org.id)/stats")
            await MainActor.run { stats = s }
        } catch { /* stats son opcionales */ }
    }
    
    private func loadDoctors() async {
        do {
            let d: [OrgDoctorResponse] = try await APIClient.shared.get("/api/v1/organizations/\(org.id)/doctors")
            await MainActor.run { doctors = d }
        } catch { /* no bloquear por esto */ }
    }
    
    // MARK: - Helpers
    
    func orgIcon(_ type: String) -> String {
        switch type {
        case "centro_medico": return "building.2.fill"
        case "clinica": return "cross.case.fill"
        case "hospital": return "building.columns.fill"
        default: return "stethoscope"
        }
    }
    
    func orgGradient(_ type: String) -> [Color] {
        switch type {
        case "centro_medico": return [.mediSky, .mediPrimary]
        case "clinica": return [.mediSuccess, Color(red: 0.10, green: 0.65, blue: 0.48)]
        case "hospital": return [.mediPrimary, .mediDeep]
        default: return [.mediCyan, .mediSky]
        }
    }
    
    func orgTypeLabel(_ type: String) -> String {
        switch type {
        case "centro_medico": return "Centro médico"
        case "clinica": return "Clínica"
        case "hospital": return "Hospital"
        case "consultorio": return "Consultorio"
        default: return "Individual"
        }
    }
    
    func roleLabel(_ role: String) -> String {
        switch role {
        case "owner": return "Propietario"
        case "admin": return "Admin"
        case "secretary": return "Secretaría"
        default: return "Médico"
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.mediNumber(22))
                .foregroundStyle(Color.mediText)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.mediTextSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.mediSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.08), radius: 8, y: 3)
    }
}

// MARK: - Create Organization View

struct CreateOrganizationView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    
    var onCreated: (() -> Void)?
    
    @State private var name = ""
    @State private var type = "consultorio"
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var city = ""
    @State private var province = "Entre Ríos"
    @State private var cuit = ""
    @State private var slotDuration = 30
    @State private var isSaving = false
    @State private var error: String?
    
    private let orgTypes = [
        ("consultorio", "Consultorio", "stethoscope"),
        ("centro_medico", "Centro médico", "building.2.fill"),
        ("clinica", "Clínica", "cross.case.fill"),
        ("hospital", "Hospital", "building.columns.fill"),
    ]
    
    private let provinces = [
        "Buenos Aires", "CABA", "Catamarca", "Chaco", "Chubut",
        "Córdoba", "Corrientes", "Entre Ríos", "Formosa", "Jujuy",
        "La Pampa", "La Rioja", "Mendoza", "Misiones", "Neuquén",
        "Río Negro", "Salta", "San Juan", "San Luis", "Santa Cruz",
        "Santa Fe", "Santiago del Estero", "Tierra del Fuego", "Tucumán"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Tipo de organización
                        VStack(alignment: .leading, spacing: 12) {
                            MediSectionHeader(title: "Tipo", icon: "building.2.fill")
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(orgTypes, id: \.0) { t in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) { type = t.0 }
                                    } label: {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(type == t.0
                                                          ? LinearGradient.medi([.mediCyan, .mediSky])
                                                          : LinearGradient.medi([Color.mediTextMuted.opacity(0.12), Color.mediTextMuted.opacity(0.06)]))
                                                    .frame(width: 42, height: 42)
                                                Image(systemName: t.2)
                                                    .font(.system(size: 18))
                                                    .foregroundStyle(type == t.0 ? .white : Color.mediTextSoft)
                                            }
                                            Text(t.1)
                                                .font(.mediCaption(13))
                                                .foregroundStyle(type == t.0 ? Color.mediPrimary : Color.mediTextSoft)
                                        }
                                        .padding(12)
                                        .frame(maxWidth: .infinity)
                                        .background(type == t.0 ? Color.mediCyan.opacity(0.06) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(type == t.0 ? Color.mediCyan.opacity(0.4) : Color.clear, lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .mediElevated()
                        
                        // Datos principales
                        VStack(alignment: .leading, spacing: 12) {
                            MediSectionHeader(title: "Datos", icon: "doc.text.fill")
                            
                            MediTextField(label: "Nombre *", text: $name, icon: "building.2",
                                          placeholder: "Ej: Consultorio Dr. García")
                            MediTextField(label: "Teléfono", text: $phone, icon: "phone",
                                          placeholder: "Ej: 0343-4123456")
                            MediTextField(label: "Email", text: $email, icon: "envelope",
                                          placeholder: "Ej: contacto@consultorio.com")
                            MediTextField(label: "CUIT", text: $cuit, icon: "doc.text",
                                          placeholder: "Ej: 20-12345678-9")
                        }
                        .mediElevated()
                        
                        // Ubicación
                        VStack(alignment: .leading, spacing: 12) {
                            MediSectionHeader(title: "Ubicación", icon: "mappin.and.ellipse")
                            
                            MediTextField(label: "Dirección", text: $address, icon: "mappin",
                                          placeholder: "Ej: Av. San Martín 1234")
                            MediTextField(label: "Ciudad", text: $city, icon: "building",
                                          placeholder: "Ej: Colón")
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Provincia")
                                    .font(.mediCaption(13))
                                    .foregroundStyle(Color.mediTextSoft)
                                Picker("Provincia", selection: $province) {
                                    ForEach(provinces, id: \.self) { p in
                                        Text(p).tag(p)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.mediPrimary)
                            }
                        }
                        .mediElevated()
                        
                        // Duración de turno
                        VStack(alignment: .leading, spacing: 12) {
                            MediSectionHeader(title: "Turnos", icon: "clock.fill")
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Duración por defecto: \(slotDuration) minutos")
                                    .font(.mediCaption(14))
                                    .foregroundStyle(Color.mediText)
                                Picker("Duración", selection: $slotDuration) {
                                    Text("15 min").tag(15)
                                    Text("20 min").tag(20)
                                    Text("30 min").tag(30)
                                    Text("45 min").tag(45)
                                    Text("60 min").tag(60)
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        .mediElevated()
                        
                        if let error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Color.mediDanger)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        
                        Button {
                            Task { await create() }
                        } label: {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Label("Crear consultorio", systemImage: "plus.circle.fill")
                            }
                        }
                        .buttonStyle(MediButtonStyle())
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                        .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Nuevo consultorio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color.mediPrimary)
                }
            }
        }
    }
    
    private func create() async {
        isSaving = true
        error = nil
        
        let req = CreateOrgRequest(
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            cuit: cuit.isEmpty ? nil : cuit,
            phone: phone.isEmpty ? nil : phone,
            email: email.isEmpty ? nil : email,
            address: address.isEmpty ? nil : address,
            city: city.isEmpty ? nil : city,
            province: province,
            defaultSlotDuration: slotDuration
        )
        
        do {
            let response: CreateOrgResponse = try await APIClient.shared.post("/api/v1/organizations", body: req)
            
            // Agregar la nueva org al AuthManager
            let newOrg = AuthManager.OrgInfo(
                id: response.organization.id,
                orgDoctorId: response.membership.id,
                name: response.organization.name,
                type: response.organization.type,
                role: "owner"
            )
            
            await MainActor.run {
                auth.organizations.append(newOrg)
                auth.selectOrganization(newOrg)
                onCreated?()
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isSaving = false
            }
        }
    }
}

// MARK: - Edit Organization View

struct EditOrganizationView: View {
    @Environment(\.dismiss) private var dismiss
    
    let orgId: String
    let current: OrgDetailResponse
    var onUpdated: (() -> Void)?
    
    @State private var name: String
    @State private var phone: String
    @State private var email: String
    @State private var address: String
    @State private var city: String
    @State private var province: String
    @State private var cuit: String
    @State private var slotDuration: Int
    @State private var isSaving = false
    @State private var error: String?
    
    init(orgId: String, current: OrgDetailResponse, onUpdated: (() -> Void)? = nil) {
        self.orgId = orgId
        self.current = current
        self.onUpdated = onUpdated
        _name = State(initialValue: current.name)
        _phone = State(initialValue: current.phone ?? "")
        _email = State(initialValue: current.email ?? "")
        _address = State(initialValue: current.address ?? "")
        _city = State(initialValue: current.city ?? "")
        _province = State(initialValue: current.province ?? "Entre Ríos")
        _cuit = State(initialValue: current.cuit ?? "")
        _slotDuration = State(initialValue: current.defaultSlotDuration ?? 30)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            MediSectionHeader(title: "Datos", icon: "doc.text.fill")
                            MediTextField(label: "Nombre", text: $name, icon: "building.2", placeholder: "")
                            MediTextField(label: "Teléfono", text: $phone, icon: "phone", placeholder: "")
                            MediTextField(label: "Email", text: $email, icon: "envelope", placeholder: "")
                            MediTextField(label: "CUIT", text: $cuit, icon: "doc.text", placeholder: "")
                        }
                        .mediElevated()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            MediSectionHeader(title: "Ubicación", icon: "mappin.and.ellipse")
                            MediTextField(label: "Dirección", text: $address, icon: "mappin", placeholder: "")
                            MediTextField(label: "Ciudad", text: $city, icon: "building", placeholder: "")
                        }
                        .mediElevated()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            MediSectionHeader(title: "Turnos", icon: "clock.fill")
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Duración: \(slotDuration) min")
                                    .font(.mediCaption(14))
                                    .foregroundStyle(Color.mediText)
                                Picker("Duración", selection: $slotDuration) {
                                    Text("15").tag(15)
                                    Text("20").tag(20)
                                    Text("30").tag(30)
                                    Text("45").tag(45)
                                    Text("60").tag(60)
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        .mediElevated()
                        
                        if let error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Color.mediDanger)
                        }
                        
                        Button {
                            Task { await save() }
                        } label: {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Label("Guardar cambios", systemImage: "checkmark.circle.fill")
                            }
                        }
                        .buttonStyle(MediButtonStyle())
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Editar consultorio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color.mediPrimary)
                }
            }
        }
    }
    
    private func save() async {
        isSaving = true
        error = nil
        
        let req = CreateOrgRequest(
            name: name.trimmingCharacters(in: .whitespaces),
            type: current.type,
            cuit: cuit.isEmpty ? nil : cuit,
            phone: phone.isEmpty ? nil : phone,
            email: email.isEmpty ? nil : email,
            address: address.isEmpty ? nil : address,
            city: city.isEmpty ? nil : city,
            province: province.isEmpty ? nil : province,
            defaultSlotDuration: slotDuration
        )
        
        do {
            let _: OrgDetailResponse = try await APIClient.shared.put("/api/v1/organizations/\(orgId)", body: req)
            await MainActor.run {
                onUpdated?()
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isSaving = false
            }
        }
    }
}

// MARK: - Invite Doctor View

struct InviteDoctorView: View {
    @Environment(\.dismiss) private var dismiss
    
    let orgId: String
    var onInvited: (() -> Void)?
    
    @State private var email = ""
    @State private var role = "doctor"
    @State private var isSending = false
    @State private var error: String?
    @State private var success = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient.medi([.mediCyan, .mediSky]))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 26))
                                    .foregroundStyle(.white)
                            }
                            .shadow(color: .mediCyan.opacity(0.3), radius: 12, y: 4)
                            
                            Text("Invitá a un colega a unirse\na tu consultorio")
                                .font(.mediHeadline(16))
                                .foregroundStyle(Color.mediText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            MediTextField(label: "Email del doctor *", text: $email,
                                          icon: "envelope", placeholder: "doctor@ejemplo.com")
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Rol")
                                    .font(.mediCaption(13))
                                    .foregroundStyle(Color.mediTextSoft)
                                Picker("Rol", selection: $role) {
                                    Text("Médico").tag("doctor")
                                    Text("Administrador").tag("admin")
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            Text(role == "admin"
                                 ? "Podrá gestionar turnos, pacientes e invitar otros médicos."
                                 : "Podrá atender pacientes y gestionar sus propios turnos.")
                            .font(.caption)
                            .foregroundStyle(Color.mediTextSoft)
                            .padding(.top, 4)
                        }
                        .mediElevated()
                        
                        if let error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Color.mediDanger)
                        }
                        
                        if success {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.mediSuccess)
                                Text("Invitación enviada")
                                    .font(.mediCaption(14))
                                    .foregroundStyle(Color.mediSuccess)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        Button {
                            Task { await sendInvite() }
                        } label: {
                            if isSending {
                                ProgressView().tint(.white)
                            } else {
                                Label("Enviar invitación", systemImage: "paperplane.fill")
                            }
                        }
                        .buttonStyle(MediButtonStyle())
                        .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || isSending || success)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Invitar médico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Color.mediPrimary)
                }
            }
        }
    }
    
    private func sendInvite() async {
        isSending = true
        error = nil
        
        let req = InviteRequest(email: email.trimmingCharacters(in: .whitespaces).lowercased(), role: role)
        
        do {
            let _: [String: String] = try await APIClient.shared.post("/api/v1/organizations/\(orgId)/invite", body: req)
            await MainActor.run {
                withAnimation { success = true }
                onInvited?()
            }
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run { dismiss() }
        } catch let err as APIError {
            await MainActor.run {
                error = err.localizedDescription
                isSending = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isSending = false
            }
        }
    }
}

// MARK: - Pending Invitations View

struct PendingInvitationsView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    
    @State private var invitations: [InvitationResponse] = []
    @State private var isLoading = true
    @State private var processingId: String?
    
    var onAccepted: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                if isLoading {
                    ProgressView().tint(.mediPrimary)
                } else if invitations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.mediTextMuted)
                        Text("No tenés invitaciones pendientes")
                            .font(.mediBody())
                            .foregroundStyle(Color.mediTextSoft)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(invitations) { inv in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(LinearGradient.medi([.mediCyan, .mediSky]))
                                                .frame(width: 42, height: 42)
                                            Image(systemName: "building.2.fill")
                                                .foregroundStyle(.white)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(inv.orgName)
                                                .font(.mediHeadline(15))
                                                .foregroundStyle(Color.mediText)
                                            Text("Invitado por \(inv.invitedByName)")
                                                .font(.caption)
                                                .foregroundStyle(Color.mediTextSoft)
                                        }
                                        Spacer()
                                        MediBadge(inv.role == "admin" ? "Admin" : "Médico", color: .mediPrimary)
                                    }
                                    
                                    Button {
                                        Task { await accept(inv) }
                                    } label: {
                                        if processingId == inv.id {
                                            ProgressView().tint(.white).frame(maxWidth: .infinity)
                                        } else {
                                            Label("Aceptar", systemImage: "checkmark.circle.fill")
                                                .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .buttonStyle(MediButtonStyle())
                                    .disabled(processingId != nil)
                                }
                                .mediElevated()
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Invitaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Color.mediPrimary)
                }
            }
            .task { await loadInvitations() }
        }
    }
    
    private func loadInvitations() async {
        do {
            let inv: [InvitationResponse] = try await APIClient.shared.get("/api/v1/invitations/received")
            await MainActor.run { invitations = inv; isLoading = false }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
    
    private func accept(_ inv: InvitationResponse) async {
        processingId = inv.id
        do {
            let _: MessageResponse = try await APIClient.shared.post("/api/v1/invitations/\(inv.id)/accept")
            
            // Recargar organizaciones del doctor
            let orgs: [[String: Any]] = try await APIClient.shared.get("/api/v1/organizations")
            // Simplificamos: removemos la invitación y recargamos al volver
            await MainActor.run {
                invitations.removeAll { $0.id == inv.id }
                processingId = nil
                onAccepted?()
            }
        } catch {
            await MainActor.run { processingId = nil }
        }
    }
}

// MARK: - Themed TextField

struct MediTextField: View {
    let label: String
    @Binding var text: String
    var icon: String = ""
    var placeholder: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.mediCaption(13))
                .foregroundStyle(Color.mediTextSoft)
            
            HStack(spacing: 10) {
                if !icon.isEmpty {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.mediCyan)
                        .frame(width: 20)
                }
                TextField(placeholder, text: $text)
                    .font(.mediBody(15))
                    .foregroundStyle(Color.mediText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(12)
            .background(Color.mediBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.mediCyan.opacity(0.2), lineWidth: 1)
            )
        }
    }
}
