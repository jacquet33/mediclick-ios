import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var showOrgPicker = false
    @State private var showNotifications = false
    @State private var showBookingSettings = false
    @State private var showCreateOrg = false
    @State private var showOrgDetail: AuthManager.OrgInfo?
    @State private var showInvitations = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Profile header with photo
                        VStack(spacing: 14) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                ZStack(alignment: .bottomTrailing) {
                                    if let profileImage {
                                        profileImage
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(LinearGradient.mediHero, lineWidth: 3))
                                    } else if let urlString = auth.avatarUrl, let url = URL(string: urlString) {
                                        AsyncImage(url: url) { img in
                                            img.resizable().scaledToFill()
                                        } placeholder: {
                                            MediAvatar(name: auth.fullName, size: 100)
                                        }
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(LinearGradient.mediHero, lineWidth: 3))
                                    } else {
                                        MediAvatar(name: auth.fullName, size: 100)
                                    }
                                    
                                    ZStack {
                                        Circle().fill(LinearGradient.mediHero).frame(width: 32, height: 32)
                                        Circle().stroke(.white, lineWidth: 2).frame(width: 32, height: 32)
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .shadow(color: .mediCyan.opacity(0.3), radius: 16, y: 6)
                            
                            VStack(spacing: 4) {
                                Text("Dr. \(auth.fullName)")
                                    .font(.mediTitle(24))
                                    .foregroundStyle(Color.mediText)
                                Text(auth.specialty)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.mediTextSoft)
                                if !auth.medicalLicense.isEmpty {
                                    MediBadge("Matrícula \(auth.medicalLicense)", color: .mediPrimary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .mediElevated(padding: 24)
                        
                        // Consultorios
                        VStack(alignment: .leading, spacing: 12) {
                            MediSectionHeader(title: "Mis consultorios", icon: "building.2.fill")
                            
                            ForEach(auth.organizations) { org in
                                Button {
                                    auth.selectOrganization(org)
                                    showOrgDetail = org
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(LinearGradient.medi(orgGradient(org.type)))
                                                .frame(width: 42, height: 42)
                                            Image(systemName: orgIcon(org.type))
                                                .font(.system(size: 18))
                                                .foregroundStyle(.white)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(org.name)
                                                .font(.mediHeadline(15))
                                                .foregroundStyle(Color.mediText)
                                            Text(orgTypeLabel(org.type) + " · " + roleLabel(org.role))
                                                .font(.caption)
                                                .foregroundStyle(Color.mediTextSoft)
                                        }
                                        
                                        Spacer()
                                        
                                        if auth.activeOrganization?.id == org.id {
                                            ZStack {
                                                Circle().fill(Color.mediSuccess.opacity(0.15)).frame(width: 26, height: 26)
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(Color.mediSuccess)
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .background(auth.activeOrganization?.id == org.id
                                                ? Color.mediCyan.opacity(0.06) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Button { showCreateOrg = true } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Agregar consultorio")
                                    Spacer()
                                }
                                .font(.mediCaption(15))
                                .foregroundStyle(Color.mediPrimary)
                                .padding(12)
                            }
                            
                            Button { showInvitations = true } label: {
                                HStack {
                                    Image(systemName: "envelope.badge")
                                    Text("Invitaciones pendientes")
                                    Spacer()
                                }
                                .font(.mediCaption(15))
                                .foregroundStyle(Color.mediSky)
                                .padding(12)
                            }
                        }
                        .mediElevated()
                        
                        // Settings
                        VStack(alignment: .leading, spacing: 4) {
                            MediSectionHeader(title: "Configuración", icon: "gearshape.fill")
                            
                            SettingRow(icon: "bell.fill", title: "Notificaciones", color: .mediWarning) {
                                showNotifications = true
                            }
                            SettingRow(icon: "link", title: "Reservas online", color: .mediSuccess) {
                                showBookingSettings = true
                            }
                            SettingRow(icon: "clock.fill", title: "Mis horarios", color: .mediCyan) { }
                            SettingRow(icon: "creditcard.fill", title: "Honorarios", color: .mediSuccess) { }
                            SettingRow(icon: "lock.fill", title: "Seguridad", color: .mediPrimary) { }
                            SettingRow(icon: "questionmark.circle.fill", title: "Ayuda", color: .mediSky) { }
                        }
                        .mediElevated()
                        
                        Button {
                            auth.logout()
                            dismiss()
                        } label: {
                            Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .buttonStyle(MediButtonStyle(colors: [.mediDanger, Color(red: 0.85, green: 0.25, blue: 0.30)]))
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Mi perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.foregroundStyle(Color.mediPrimary)
                }
            }
            .sheet(isPresented: $showNotifications) { NotificationsView() }
            .sheet(isPresented: $showBookingSettings) { BookingSettingsView() }
            .sheet(isPresented: $showCreateOrg) {
                CreateOrganizationView()
                    .environment(auth)
            }
            .sheet(item: $showOrgDetail) { org in
                OrganizationDetailView(org: org)
                    .environment(auth)
            }
            .sheet(isPresented: $showInvitations) {
                PendingInvitationsView {
                    // Recargar orgs del doctor al aceptar invitación
                    Task { await reloadOrganizations() }
                }
                .environment(auth)
            }
            .onChange(of: selectedPhoto) {
                Task {
                    if let data = try? await selectedPhoto?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        profileImage = Image(uiImage: uiImage)
                        auth.saveProfileImage(data)
                    }
                }
            }
            .onAppear {
                if let data = auth.loadProfileImage(), let uiImage = UIImage(data: data) {
                    profileImage = Image(uiImage: uiImage)
                }
            }
        }
    }
    
    // MARK: - Reload orgs from API
    
    func reloadOrganizations() async {
        struct OrgRow: Decodable {
            let orgId: String
            let orgDoctorId: String
            let orgName: String
            let orgType: String
            let role: String
        }
        
        do {
            let rows: [OrgRow] = try await APIClient.shared.get("/api/v1/organizations")
            let newOrgs = rows.map { r in
                AuthManager.OrgInfo(id: r.orgId, orgDoctorId: r.orgDoctorId,
                                    name: r.orgName, type: r.orgType, role: r.role)
            }
            await MainActor.run {
                auth.organizations = newOrgs
                // Mantener la selección activa si sigue existiendo
                if let activeId = auth.activeOrganization?.id,
                   let match = newOrgs.first(where: { $0.id == activeId }) {
                    auth.selectOrganization(match)
                } else if let first = newOrgs.first {
                    auth.selectOrganization(first)
                }
            }
        } catch { /* silencioso si falla */ }
    }
    
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
        case "admin": return "Administrador"
        case "secretary": return "Secretaría"
        default: return "Médico"
        }
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                        .shadow(color: color.opacity(0.18), radius: 4, y: 2)
                        .shadow(color: Color.black.opacity(0.04), radius: 1, y: 0.5)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.mediText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.mediTextMuted)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reminder Settings API Model

struct ReminderSettings: Codable {
    var appointmentReminderEnabled: Bool
    var appointmentReminderMinutes: [Int]
    var appointmentReminderPush: Bool
    var appointmentReminderEmail: Bool
    var dailySummaryEnabled: Bool
    var dailySummaryTime: String
    var dailySummaryDays: [Int]
    var newMessageEnabled: Bool
    var newMessagePush: Bool
    var newMessageSound: Bool
    var prescriptionExpiryEnabled: Bool
    var prescriptionExpiryDays: Int
    var cancellationAlertEnabled: Bool
    var noShowAlertEnabled: Bool
    var quietHoursEnabled: Bool
    var quietHoursStart: String
    var quietHoursEnd: String
    var crossOrgConflictEnabled: Bool
    
    static let defaults = ReminderSettings(
        appointmentReminderEnabled: true, appointmentReminderMinutes: [30],
        appointmentReminderPush: true, appointmentReminderEmail: false,
        dailySummaryEnabled: false, dailySummaryTime: "08:00", dailySummaryDays: [1,2,3,4,5],
        newMessageEnabled: true, newMessagePush: true, newMessageSound: true,
        prescriptionExpiryEnabled: true, prescriptionExpiryDays: 7,
        cancellationAlertEnabled: true, noShowAlertEnabled: true,
        quietHoursEnabled: false, quietHoursStart: "22:00", quietHoursEnd: "07:00",
        crossOrgConflictEnabled: true
    )
}

// MARK: - Notifications / Reminder Settings View

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = ReminderSettings.defaults
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var hasChanges = false
    @State private var showSaved = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                if isLoading {
                    ProgressView().tint(.mediPrimary)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            appointmentSection
                            dailySummarySection
                            messagesSection
                            prescriptionsSection
                            cancellationsSection
                            quietHoursSection
                            conflictSection
                        }
                        .padding(20)
                        .padding(.bottom, 30)
                    }
                }
                
                // Feedback flotante
                if showSaved {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Guardado")
                        }
                        .font(.mediCaption(14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(LinearGradient.medi([.mediSuccess, Color(red: 0.10, green: 0.65, blue: 0.48)]))
                        )
                        .shadow(color: .mediSuccess.opacity(0.4), radius: 12, y: 4)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("Recordatorios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Color.mediPrimary)
                }
                ToolbarItem(placement: .primaryAction) {
                    if hasChanges {
                        Button {
                            Task { await save() }
                        } label: {
                            if isSaving {
                                ProgressView().tint(.mediPrimary)
                            } else {
                                Text("Guardar")
                                    .font(.mediCaption(15))
                                    .foregroundStyle(Color.mediPrimary)
                            }
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .task { await loadSettings() }
        }
    }
    
    // MARK: - Turnos
    
    private var appointmentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MediSectionHeader(title: "Recordatorio de turnos", icon: "calendar.badge.clock")
            
            NotifToggle(
                icon: "bell.fill",
                title: "Recordatorios activos",
                subtitle: "Recibir aviso antes de cada turno",
                color: .mediCyan,
                isOn: binding(\.appointmentReminderEnabled)
            )
            
            if settings.appointmentReminderEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Avisar con anticipación")
                        .font(.mediCaption(13))
                        .foregroundStyle(Color.mediTextSoft)
                    
                    ReminderMinutesPicker(
                        selected: Binding(
                            get: { settings.appointmentReminderMinutes },
                            set: { settings.appointmentReminderMinutes = $0; hasChanges = true }
                        )
                    )
                }
                .padding(.leading, 50)
                .transition(.opacity.combined(with: .move(edge: .top)))
                
                HStack(spacing: 20) {
                    ChannelToggle(icon: "iphone.radiowaves.left.and.right", label: "Push",
                                  isOn: binding(\.appointmentReminderPush))
                    ChannelToggle(icon: "envelope.fill", label: "Email",
                                  isOn: binding(\.appointmentReminderEmail))
                }
                .padding(.leading, 50)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .mediElevated()
        .animation(.easeInOut(duration: 0.25), value: settings.appointmentReminderEnabled)
    }
    
    // MARK: - Resumen diario
    
    private var dailySummarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MediSectionHeader(title: "Resumen diario", icon: "chart.bar.fill")
            
            NotifToggle(
                icon: "sun.max.fill",
                title: "Agenda del día",
                subtitle: "Resumen con los turnos programados",
                color: .mediSuccess,
                isOn: binding(\.dailySummaryEnabled)
            )
            
            if settings.dailySummaryEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    // Hora
                    HStack {
                        Text("Hora de envío")
                            .font(.mediCaption(13))
                            .foregroundStyle(Color.mediTextSoft)
                        Spacer()
                        TimePicker(time: Binding(
                            get: { settings.dailySummaryTime },
                            set: { settings.dailySummaryTime = $0; hasChanges = true }
                        ))
                    }
                    
                    // Días
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Días de la semana")
                            .font(.mediCaption(13))
                            .foregroundStyle(Color.mediTextSoft)
                        DaysPicker(
                            selected: Binding(
                                get: { settings.dailySummaryDays },
                                set: { settings.dailySummaryDays = $0; hasChanges = true }
                            )
                        )
                    }
                }
                .padding(.leading, 50)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .mediElevated()
        .animation(.easeInOut(duration: 0.25), value: settings.dailySummaryEnabled)
    }
    
    // MARK: - Mensajes
    
    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MediSectionHeader(title: "Mensajes de pacientes", icon: "message.fill")
            
            NotifToggle(
                icon: "bubble.left.fill",
                title: "Mensajes nuevos",
                subtitle: "Cuando un paciente escribe",
                color: .mediSky,
                isOn: binding(\.newMessageEnabled)
            )
            
            if settings.newMessageEnabled {
                HStack(spacing: 20) {
                    ChannelToggle(icon: "iphone.radiowaves.left.and.right", label: "Push",
                                  isOn: binding(\.newMessagePush))
                    ChannelToggle(icon: "speaker.wave.2.fill", label: "Sonido",
                                  isOn: binding(\.newMessageSound))
                }
                .padding(.leading, 50)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .mediElevated()
        .animation(.easeInOut(duration: 0.25), value: settings.newMessageEnabled)
    }
    
    // MARK: - Recetas
    
    private var prescriptionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MediSectionHeader(title: "Recetas", icon: "cross.case.fill")
            
            NotifToggle(
                icon: "exclamationmark.triangle.fill",
                title: "Recetas por vencer",
                subtitle: settings.prescriptionExpiryEnabled
                    ? "\(settings.prescriptionExpiryDays) días antes del vencimiento"
                    : "Desactivado",
                color: .mediWarning,
                isOn: binding(\.prescriptionExpiryEnabled)
            )
            
            if settings.prescriptionExpiryEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Días de anticipación")
                        .font(.mediCaption(13))
                        .foregroundStyle(Color.mediTextSoft)
                    Picker("Días", selection: Binding(
                        get: { settings.prescriptionExpiryDays },
                        set: { settings.prescriptionExpiryDays = $0; hasChanges = true }
                    )) {
                        Text("3 días").tag(3)
                        Text("5 días").tag(5)
                        Text("7 días").tag(7)
                        Text("14 días").tag(14)
                        Text("30 días").tag(30)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.leading, 50)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .mediElevated()
        .animation(.easeInOut(duration: 0.25), value: settings.prescriptionExpiryEnabled)
    }
    
    // MARK: - Cancelaciones
    
    private var cancellationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MediSectionHeader(title: "Cancelaciones", icon: "xmark.circle.fill")
            
            NotifToggle(
                icon: "calendar.badge.minus",
                title: "Turno cancelado",
                subtitle: "Cuando un paciente cancela",
                color: .mediDanger,
                isOn: binding(\.cancellationAlertEnabled)
            )
            
            NotifToggle(
                icon: "person.slash.fill",
                title: "Paciente ausente",
                subtitle: "Cuando no se presenta al turno",
                color: Color(red: 0.85, green: 0.25, blue: 0.30),
                isOn: binding(\.noShowAlertEnabled)
            )
        }
        .mediElevated()
    }
    
    // MARK: - Horario silencioso
    
    private var quietHoursSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MediSectionHeader(title: "Horario silencioso", icon: "moon.fill")
            
            NotifToggle(
                icon: "moon.zzz.fill",
                title: "No molestar",
                subtitle: settings.quietHoursEnabled
                    ? "De \(settings.quietHoursStart) a \(settings.quietHoursEnd)"
                    : "Desactivado",
                color: .mediDeep,
                isOn: binding(\.quietHoursEnabled)
            )
            
            if settings.quietHoursEnabled {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Desde")
                            .font(.mediCaption(12))
                            .foregroundStyle(Color.mediTextSoft)
                        TimePicker(time: Binding(
                            get: { settings.quietHoursStart },
                            set: { settings.quietHoursStart = $0; hasChanges = true }
                        ))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hasta")
                            .font(.mediCaption(12))
                            .foregroundStyle(Color.mediTextSoft)
                        TimePicker(time: Binding(
                            get: { settings.quietHoursEnd },
                            set: { settings.quietHoursEnd = $0; hasChanges = true }
                        ))
                    }
                }
                .padding(.leading, 50)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .mediElevated()
        .animation(.easeInOut(duration: 0.25), value: settings.quietHoursEnabled)
    }
    
    // MARK: - Conflictos
    
    private var conflictSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MediSectionHeader(title: "Multi-consultorio", icon: "building.2.fill")
            
            NotifToggle(
                icon: "exclamationmark.2",
                title: "Conflictos de horarios",
                subtitle: "Aviso si un turno se superpone con otro consultorio",
                color: .mediPrimary,
                isOn: binding(\.crossOrgConflictEnabled)
            )
        }
        .mediElevated()
    }
    
    // MARK: - Helpers
    
    private func binding(_ keyPath: WritableKeyPath<ReminderSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { settings[keyPath: keyPath] = $0; hasChanges = true }
        )
    }
    
    // MARK: - API
    
    private func loadSettings() async {
        do {
            let s: ReminderSettings = try await APIClient.shared.get("/api/v1/reminder-settings")
            await MainActor.run { settings = s; isLoading = false }
        } catch {
            // Si falla, usar defaults
            await MainActor.run { isLoading = false }
        }
    }
    
    private func save() async {
        isSaving = true
        do {
            let updated: ReminderSettings = try await APIClient.shared.put("/api/v1/reminder-settings", body: settings)
            await MainActor.run {
                settings = updated
                hasChanges = false
                isSaving = false
                withAnimation(.spring(duration: 0.3)) { showSaved = true }
            }
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) { showSaved = false }
            }
        } catch {
            await MainActor.run { isSaving = false }
        }
    }
}

// MARK: - Reminder Minutes Picker (multi-select chips)

struct ReminderMinutesPicker: View {
    @Binding var selected: [Int]
    
    private let options: [(Int, String)] = [
        (10, "10 min"), (15, "15 min"), (30, "30 min"),
        (60, "1 hora"), (120, "2 horas"), (1440, "1 día")
    ]
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
            ForEach(options, id: \.0) { value, label in
                let isActive = selected.contains(value)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if isActive {
                            // No dejar vacío
                            if selected.count > 1 { selected.removeAll { $0 == value } }
                        } else {
                            selected.append(value)
                            selected.sort()
                        }
                    }
                } label: {
                    Text(label)
                        .font(.mediCaption(12))
                        .foregroundStyle(isActive ? .white : Color.mediTextSoft)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            isActive
                                ? AnyShapeStyle(LinearGradient.medi([.mediCyan, .mediSky]))
                                : AnyShapeStyle(Color.mediBgSoft)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isActive ? Color.clear : Color.mediCyan.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Days Picker (week day buttons)

struct DaysPicker: View {
    @Binding var selected: [Int]
    
    private let days: [(Int, String)] = [
        (1, "L"), (2, "M"), (3, "X"), (4, "J"), (5, "V"), (6, "S"), (0, "D")
    ]
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.0) { value, label in
                let isActive = selected.contains(value)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if isActive {
                            if selected.count > 1 { selected.removeAll { $0 == value } }
                        } else {
                            selected.append(value)
                        }
                    }
                } label: {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(isActive ? .white : Color.mediTextSoft)
                        .frame(width: 36, height: 36)
                        .background(
                            isActive
                                ? AnyShapeStyle(LinearGradient.medi([.mediCyan, .mediSky]))
                                : AnyShapeStyle(Color.mediBgSoft)
                        )
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(isActive ? Color.clear : Color.mediCyan.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Time Picker (hour:minute selector)

struct TimePicker: View {
    @Binding var time: String
    
    private var date: Binding<Date> {
        Binding(
            get: {
                let parts = time.split(separator: ":").compactMap { Int($0) }
                var components = DateComponents()
                components.hour = parts.first ?? 8
                components.minute = parts.count > 1 ? parts[1] : 0
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                time = String(format: "%02d:%02d", c.hour ?? 8, c.minute ?? 0)
            }
        )
    }
    
    var body: some View {
        DatePicker("", selection: date, displayedComponents: .hourAndMinute)
            .labelsHidden()
            .tint(.mediPrimary)
    }
}

// MARK: - Channel Toggle (small inline toggle)

struct ChannelToggle: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool
    
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { isOn.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.mediCaption(12))
            }
            .foregroundStyle(isOn ? .white : Color.mediTextSoft)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                isOn
                    ? AnyShapeStyle(LinearGradient.medi([.mediCyan, .mediSky]))
                    : AnyShapeStyle(Color.mediBgSoft)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isOn ? Color.clear : Color.mediCyan.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - NotifToggle (reusable toggle row)

struct NotifToggle: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(LinearGradient.medi([color.opacity(0.2), color.opacity(0.08)]))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.mediCaption(15))
                    .foregroundStyle(Color.mediText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.mediTextSoft)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(color)
        }
    }
}

