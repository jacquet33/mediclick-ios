import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalAppointment.startTime) private var todayAppointments: [LocalAppointment]
    @Query private var patients: [LocalPatient]
    @State private var showOrgPicker = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Greeting
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Buenos días")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Dr. \(auth.currentDoctor?.lastName ?? "Doctor")")
                            .font(.title.bold())
                    }
                    .padding(.horizontal)
                    
                    // Org selector
                    if let org = auth.activeOrganization {
                        Button { showOrgPicker = true } label: {
                            HStack {
                                Image(systemName: orgIcon(org.type))
                                    .foregroundStyle(.blue)
                                Text(org.name)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .padding(12)
                            .background(.gray.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                    
                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(title: "Turnos hoy", value: "\(todayAppointments.count)", color: .blue)
                        StatCard(title: "Pacientes", value: "\(patients.count)", color: .green)
                        StatCard(title: "Recetas", value: "23", color: .primary)
                        StatCard(title: "Mensajes", value: "5", color: .orange)
                    }
                    .padding(.horizontal)
                    
                    // Upcoming appointments
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PRÓXIMOS TURNOS")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        if todayAppointments.isEmpty {
                            ContentUnavailableView {
                                Label("Sin turnos hoy", systemImage: "calendar")
                            } description: {
                                Text("No hay turnos programados para hoy")
                            }
                            .frame(height: 200)
                        } else {
                            ForEach(todayAppointments.prefix(5)) { appt in
                                AppointmentRow(appointment: appt)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Sync status
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Mi perfil", systemImage: "person.circle") { }
                        Button("Configuración", systemImage: "gear") { }
                        Divider()
                        Button("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            auth.logout()
                        }
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showOrgPicker) {
                OrgPickerView()
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
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Appointment Row

struct AppointmentRow: View {
    let appointment: LocalAppointment
    
    var statusColor: Color {
        switch appointment.status {
        case "confirmed": return .green
        case "pending": return .orange
        case "in_progress": return .blue
        case "completed": return .gray
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(appointment.formattedStartTime)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.blue)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(appointment.patient?.fullName ?? "Paciente")
                    .font(.subheadline.weight(.medium))
                Text(appointment.reason ?? "Consulta")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(appointment.status == "confirmed" ? "Conf." : "Pend.")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15))
                .foregroundStyle(statusColor)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.gray.opacity(0.15), lineWidth: 0.5)
        )
    }
}



// MARK: - Org Picker

struct OrgPickerView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(auth.organizations) { org in
                Button {
                    auth.selectOrganization(org)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(org.name)
                                .font(.body.weight(.medium))
                            Text("\(org.type) · \(org.role)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if auth.activeOrganization?.id == org.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Mis consultorios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
