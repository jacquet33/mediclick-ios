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
                Color.mediBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header with gradient
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Buenos días")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.8))
                                    Text("Dr. \(auth.currentDoctor?.lastName ?? "Doctor")")
                                        .font(.title.bold())
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(.white.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    Image(systemName: "stethoscope")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            LinearGradient(
                                colors: [Color.mediPrimary, Color.mediPrimaryLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                        
                        // Stats
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCardMedi(icon: "calendar.badge.clock", title: "Turnos hoy", value: "\(todayAppointments.count)", color: .mediPrimary)
                            StatCardMedi(icon: "person.2.fill", title: "Pacientes", value: "\(patients.count)", color: .mediSuccess)
                            StatCardMedi(icon: "doc.text.fill", title: "Recetas", value: "23", color: .mediPrimaryLight)
                            StatCardMedi(icon: "message.fill", title: "Mensajes", value: "5", color: .mediWarning)
                        }
                        .padding(.horizontal)
                        
                        // Próximos turnos
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(Color.mediPrimary)
                                Text("PRÓXIMOS TURNOS")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.mediTextSecondary)
                            }
                            .padding(.horizontal)
                            
                            if todayAppointments.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.checkmark")
                                        .font(.system(size: 40))
                                        .foregroundStyle(Color.mediPrimary.opacity(0.4))
                                    Text("Sin turnos programados")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.mediTextSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                                .mediCard()
                                .padding(.horizontal)
                            } else {
                                ForEach(todayAppointments.prefix(5)) { appt in
                                    AppointmentRowMedi(appointment: appt)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { } label: {
                            Label("Mi perfil", systemImage: "person.circle")
                        }
                        Button { } label: {
                            Label("Configuración", systemImage: "gear")
                        }
                        Divider()
                        Button(role: .destructive) { auth.logout() } label: {
                            Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.mediPrimary)
                    }
                }
            }
        }
    }
}

// MARK: - Stat Card Medical

struct StatCardMedi: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.mediTextSecondary)
        }
        .mediCard()
    }
}

// MARK: - Appointment Row Medical

struct AppointmentRowMedi: View {
    let appointment: LocalAppointment
    
    var body: some View {
        HStack(spacing: 14) {
            // Time pill
            VStack(spacing: 2) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(Color.mediPrimary)
                Text(appointment.formattedStartTime)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mediPrimary)
            }
            .frame(width: 55)
            .padding(.vertical, 8)
            .background(Color.mediPrimary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.patient?.fullName ?? "Paciente")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.mediTextPrimary)
                HStack(spacing: 4) {
                    Image(systemName: "cross.case")
                        .font(.caption2)
                    Text(appointment.reason ?? "Consulta")
                        .font(.caption)
                }
                .foregroundStyle(Color.mediTextSecondary)
            }
            
            Spacer()
            
            MediBadge(
                MediStatus.label(for: appointment.status),
                color: MediStatus.color(for: appointment.status),
                bgColor: MediStatus.bgColor(for: appointment.status)
            )
        }
        .mediCard()
    }
}
