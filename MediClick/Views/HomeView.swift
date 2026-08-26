import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalAppointment.startTime) private var todayAppointments: [LocalAppointment]
    @Query private var patients: [LocalPatient]
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        // Hero header
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Buenos días")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.85))
                                    Text("Dr. \(auth.currentDoctor?.lastName ?? "Doctor")")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                ZStack {
                                    Circle().fill(.white.opacity(0.18)).frame(width: 56, height: 56)
                                    Circle().stroke(.white.opacity(0.35), lineWidth: 1).frame(width: 56, height: 56)
                                    Image(systemName: "stethoscope")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundStyle(.white)
                                }
                            }
                            
                            Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.top, 4)
                        }
                        .padding(22)
                        .background(
                            ZStack {
                                LinearGradient.mediHero
                                LinearGradient.mediShine
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(.white.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: .mediPrimary.opacity(0.35), radius: 22, y: 10)
                        
                        // Stats grid
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                            StatCardPro(icon: "calendar.badge.clock", title: "Turnos hoy",
                                        value: "\(todayAppointments.count)", colors: [.mediCyan, .mediSky])
                            StatCardPro(icon: "person.2.fill", title: "Pacientes",
                                        value: "\(patients.count)", colors: [.mediSuccess, Color(red: 0.10, green: 0.65, blue: 0.48)])
                            StatCardPro(icon: "cross.case.fill", title: "Recetas",
                                        value: "23", colors: [.mediSky, .mediPrimary])
                            StatCardPro(icon: "message.fill", title: "Mensajes",
                                        value: "5", colors: [.mediWarning, Color(red: 0.95, green: 0.55, blue: 0.10)])
                        }
                        
                        // Appointments
                        VStack(alignment: .leading, spacing: 14) {
                            MediSectionHeader(title: "Próximos turnos", icon: "clock.fill")
                            
                            if todayAppointments.isEmpty {
                                VStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient.medi([.mediCyan.opacity(0.15), .mediSky.opacity(0.05)]))
                                            .frame(width: 80, height: 80)
                                        Image(systemName: "calendar.badge.checkmark")
                                            .font(.system(size: 34))
                                            .foregroundStyle(LinearGradient.medi([.mediCyan, .mediSky]))
                                    }
                                    Text("Sin turnos programados")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.mediTextSoft)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 36)
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
                    Menu {
                        Button { } label: { Label("Mi perfil", systemImage: "person.circle") }
                        Button { } label: { Label("Configuración", systemImage: "gear") }
                        Divider()
                        Button(role: .destructive) { auth.logout() } label: {
                            Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.medi([.mediCyan.opacity(0.15), .mediSky.opacity(0.1)]))
                                .frame(width: 36, height: 36)
                            Image(systemName: "person.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(LinearGradient.medi([.mediPrimary, .mediDeep]))
                        }
                    }
                }
            }
        }
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
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.25))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
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
            // Time badge with gradient
            VStack(spacing: 3) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                Text(appointment.formattedStartTime)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(width: 58, height: 52)
            .background(
                ZStack {
                    LinearGradient.medi(MediStatus.gradient(for: appointment.status))
                    LinearGradient.mediShine
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: MediStatus.color(for: appointment.status).opacity(0.3), radius: 8, y: 3)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(appointment.patient?.fullName ?? "Paciente")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mediText)
                HStack(spacing: 5) {
                    Image(systemName: "cross.case.fill").font(.system(size: 9))
                    Text(appointment.reason ?? "Consulta")
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(Color.mediTextSoft)
            }
            
            Spacer()
            
            MediBadge(
                MediStatus.label(for: appointment.status),
                color: MediStatus.color(for: appointment.status)
            )
        }
        .mediElevated(padding: 14)
    }
}
