import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalAppointment.startTime) private var appointments: [LocalAppointment]
    @Query private var patients: [LocalPatient]
    @Query private var prescriptions: [LocalPrescription]
    @Query private var conversations: [LocalConversation]
    
    @Binding var selectedTab: Int
    @State private var showProfile = false
    @State private var showOrgPicker = false
    
    private var todayAppointments: [LocalAppointment] {
        appointments.filter { Calendar.current.isDateInToday($0.date) && $0.status != "cancelled" }
    }
    private var unreadCount: Int {
        conversations.reduce(0) { $0 + $1.doctorUnreadCount }
    }
    private var activeRx: Int {
        prescriptions.filter { $0.status == "active" }.count
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        // Hero
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(greeting)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.85))
                                    Text("Dr. \(auth.lastName.isEmpty ? "Doctor" : auth.lastName)")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                Button { showProfile = true } label: {
                                    ZStack {
                                        Circle().fill(.white.opacity(0.2)).frame(width: 54, height: 54)
                                        Circle().stroke(.white.opacity(0.4), lineWidth: 1.5).frame(width: 54, height: 54)
                                        if let data = auth.loadProfileImage(), let ui = UIImage(data: data) {
                                            Image(uiImage: ui).resizable().scaledToFill()
                                                .frame(width: 50, height: 50).clipShape(Circle())
                                        } else {
                                            Image(systemName: "stethoscope")
                                                .font(.system(size: 23, weight: .medium))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                            }
                            
                            // Org selector
                            if let org = auth.activeOrganization {
                                Button { showOrgPicker = true } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "building.2.fill").font(.caption)
                                        Text(org.name).font(.caption.weight(.semibold)).lineLimit(1)
                                        if auth.organizations.count > 1 {
                                            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                                        }
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(.white.opacity(0.18))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
                                }
                            }
                        }
                        .padding(22)
                        .background(ZStack { LinearGradient.mediHero; LinearGradient.mediShine })
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.25), lineWidth: 1))
                        .shadow(color: .mediPrimary.opacity(0.35), radius: 22, y: 10)
                        
                        // Stats — tappable
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                            Button { selectedTab = 1 } label: {
                                StatCardPro(icon: "calendar.badge.clock", title: "Turnos hoy",
                                            value: "\(todayAppointments.count)", colors: [.mediCyan, .mediSky])
                            }.buttonStyle(.plain)
                            
                            Button { selectedTab = 2 } label: {
                                StatCardPro(icon: "person.2.fill", title: "Pacientes",
                                            value: "\(patients.count)",
                                            colors: [.mediSuccess, Color(red: 0.10, green: 0.65, blue: 0.48)])
                            }.buttonStyle(.plain)
                            
                            Button { selectedTab = 3 } label: {
                                StatCardPro(icon: "cross.case.fill", title: "Recetas",
                                            value: "\(activeRx)", colors: [.mediSky, .mediPrimary])
                            }.buttonStyle(.plain)
                            
                            Button { selectedTab = 4 } label: {
                                StatCardPro(icon: "message.fill", title: "Mensajes",
                                            value: "\(unreadCount)",
                                            colors: [.mediWarning, Color(red: 0.95, green: 0.55, blue: 0.10)])
                            }.buttonStyle(.plain)
                        }
                        
                        // Quick actions
                        VStack(alignment: .leading, spacing: 12) {
                            MediSectionHeader(title: "Acciones rápidas", icon: "bolt.fill")
                            HStack(spacing: 12) {
                                QuickAction(icon: "person.badge.plus", title: "Paciente", colors: [.mediSuccess, .mediCyan]) {
                                    selectedTab = 2
                                }
                                QuickAction(icon: "calendar.badge.plus", title: "Turno", colors: [.mediCyan, .mediSky]) {
                                    selectedTab = 1
                                }
                                QuickAction(icon: "doc.badge.plus", title: "Receta", colors: [.mediSky, .mediPrimary]) {
                                    selectedTab = 3
                                }
                            }
                        }
                        
                        // Appointments
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                MediSectionHeader(title: "Próximos turnos", icon: "clock.fill")
                                if !todayAppointments.isEmpty {
                                    Button("Ver todos") { selectedTab = 1 }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.mediPrimary)
                                }
                            }
                            
                            if todayAppointments.isEmpty {
                                EmptyStateMedi(icon: "calendar.badge.checkmark",
                                               title: "Sin turnos hoy",
                                               subtitle: "Tu agenda de hoy está libre")
                                .mediGlass()
                            } else {
                                ForEach(todayAppointments.prefix(5)) { appt in
                                    AppointmentRowPro(appointment: appt)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        ZStack {
                            Circle().fill(LinearGradient.medi([.mediCyan.opacity(0.15), .mediSky.opacity(0.1)]))
                                .frame(width: 36, height: 36)
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(LinearGradient.medi([.mediPrimary, .mediDeep]))
                        }
                    }
                }
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .confirmationDialog("Cambiar consultorio", isPresented: $showOrgPicker, titleVisibility: .visible) {
                ForEach(auth.organizations) { org in
                    Button(org.name) { auth.selectOrganization(org) }
                }
            }
        }
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Buenos días"
        case 12..<19: return "Buenas tardes"
        default: return "Buenas noches"
        }
    }
}

struct QuickAction: View {
    let icon: String
    let title: String
    let colors: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient.medi(colors.map { $0.opacity(0.15) }))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(LinearGradient.medi(colors))
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.mediText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(LinearGradient.mediBorder, lineWidth: 1))
            .shadow(color: .mediPrimary.opacity(0.08), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct StatCardPro: View {
    let icon: String
    let title: String
    let value: String
    let colors: [Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.25)).frame(width: 38, height: 38)
                Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            }
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mediGradientCard(colors, padding: 16)
    }
}

struct AppointmentRowPro: View {
    let appointment: LocalAppointment
    
    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 3) {
                Image(systemName: "clock.fill").font(.system(size: 10))
                Text(appointment.formattedStartTime)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(width: 58, height: 52)
            .background(ZStack {
                LinearGradient.medi(MediStatus.gradient(for: appointment.status))
                LinearGradient.mediShine
            })
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: MediStatus.color(for: appointment.status).opacity(0.3), radius: 8, y: 3)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(appointment.patient?.fullName ?? "Paciente")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mediText)
                HStack(spacing: 5) {
                    Image(systemName: "cross.case.fill").font(.system(size: 9))
                    Text(appointment.reason ?? "Consulta").font(.caption).lineLimit(1)
                }
                .foregroundStyle(Color.mediTextSoft)
            }
            
            Spacer()
            
            MediBadge(MediStatus.label(for: appointment.status),
                      color: MediStatus.color(for: appointment.status))
        }
        .mediElevated(padding: 14)
    }
}
