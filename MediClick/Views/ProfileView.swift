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
                            
                            Button {
                                // Add new org
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Agregar consultorio")
                                    Spacer()
                                }
                                .font(.mediCaption(15))
                                .foregroundStyle(Color.mediPrimary)
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
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.mediText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.mediTextMuted)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notifications

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appointmentReminders = true
    @State private var newMessages = true
    @State private var prescriptionAlerts = true
    @State private var dailySummary = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 16) {
                            MediSectionHeader(title: "Alertas", icon: "bell.badge.fill")
                            
                            NotifToggle(icon: "calendar.badge.clock", title: "Recordatorio de turnos",
                                        subtitle: "30 min antes de cada turno", color: .mediCyan, isOn: $appointmentReminders)
                            NotifToggle(icon: "message.fill", title: "Mensajes nuevos",
                                        subtitle: "Cuando un paciente escribe", color: .mediSky, isOn: $newMessages)
                            NotifToggle(icon: "cross.case.fill", title: "Recetas por vencer",
                                        subtitle: "7 días antes del vencimiento", color: .mediWarning, isOn: $prescriptionAlerts)
                            NotifToggle(icon: "chart.bar.fill", title: "Resumen diario",
                                        subtitle: "Agenda del día a las 8:00", color: .mediSuccess, isOn: $dailySummary)
                        }
                        .mediElevated()
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Notificaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Listo") { dismiss() }.foregroundStyle(Color.mediPrimary)
                }
            }
        }
    }
}

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
