import SwiftUI
import SwiftData

struct AgendaView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalAppointment.startTime) private var appointments: [LocalAppointment]
    @State private var selectedDate = Date()
    @State private var showNewAppointment = false
    
    private var weekDates: [Date] {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }
    
    private var dayAppointments: [LocalAppointment] {
        appointments.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                VStack(spacing: 0) {
                    // Week strip
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(weekDates, id: \.self) { date in
                                DayChip(date: date,
                                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                                        count: appointments.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.count) {
                                    withAnimation(.spring(response: 0.3)) { selectedDate = date }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            if dayAppointments.isEmpty {
                                EmptyStateMedi(
                                    icon: "calendar.badge.plus",
                                    title: "Sin turnos",
                                    subtitle: "No hay turnos para este día",
                                    actionTitle: "Agendar turno"
                                ) { showNewAppointment = true }
                                .padding(.top, 60)
                            } else {
                                ForEach(dayAppointments) { appt in
                                    NavigationLink {
                                        AppointmentDetailView(appointment: appt)
                                    } label: {
                                        AppointmentRowPro(appointment: appt)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Agenda")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewAppointment = true } label: {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.mediHero)
                                .frame(width: 34, height: 34)
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: .mediCyan.opacity(0.4), radius: 8, y: 3)
                    }
                }
            }
            .sheet(isPresented: $showNewAppointment) { NewAppointmentView() }
        }
    }
}

struct DayChip: View {
    let date: Date
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    private var dayName: String { date.formatted(.dateTime.weekday(.abbreviated)).capitalized }
    private var dayNumber: String { date.formatted(.dateTime.day()) }
    private var isToday: Bool { Calendar.current.isDateInToday(date) }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(dayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : Color.mediTextSoft)
                Text(dayNumber)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : Color.mediText)
                if count > 0 {
                    Circle()
                        .fill(isSelected ? .white : Color.mediCyan)
                        .frame(width: 5, height: 5)
                } else {
                    Circle().fill(.clear).frame(width: 5, height: 5)
                }
            }
            .frame(width: 52, height: 72)
            .background(
                ZStack {
                    if isSelected {
                        LinearGradient.mediHero
                        LinearGradient.mediShine
                    } else {
                        Color.white.opacity(0.7)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? .white.opacity(0.3) : (isToday ? Color.mediCyan.opacity(0.5) : Color.mediPrimary.opacity(0.12)),
                            lineWidth: isToday && !isSelected ? 1.5 : 1)
            )
            .shadow(color: isSelected ? .mediCyan.opacity(0.35) : .mediPrimary.opacity(0.06),
                    radius: isSelected ? 12 : 4, y: isSelected ? 5 : 1)
        }
        .buttonStyle(.plain)
    }
}

struct AppointmentDetailView: View {
    let appointment: LocalAppointment
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack {
            MediBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 12) {
                        MediAvatar(name: appointment.patient?.fullName ?? "?", size: 64)
                        Text(appointment.patient?.fullName ?? "Paciente")
                            .font(.mediTitle(21))
                            .foregroundStyle(Color.mediText)
                        MediBadge(MediStatus.label(for: appointment.status),
                                  color: MediStatus.color(for: appointment.status))
                    }
                    .frame(maxWidth: .infinity)
                    .mediElevated(padding: 20)
                    
                    VStack(spacing: 12) {
                        MediSectionHeader(title: "Detalle del turno", icon: "calendar")
                        MediInfoRow(icon: "calendar", label: "Fecha", value: appointment.date.formatted(date: .long, time: .omitted))
                        MediInfoRow(icon: "clock.fill", label: "Hora", value: appointment.formattedStartTime)
                        if let reason = appointment.reason {
                            MediInfoRow(icon: "cross.case.fill", label: "Motivo", value: reason)
                        }
                        if appointment.isFirstVisit {
                            MediInfoRow(icon: "star.fill", label: "Tipo", value: "Primera visita")
                        }
                    }
                    .mediElevated()
                    
                    VStack(spacing: 10) {
                        if appointment.status == "pending" {
                            Button {
                                Task { await changeApptStatus(appointment, to: "confirmed") }
                            } label: {
                                Label("Confirmar turno", systemImage: "checkmark.circle.fill")
                            }
                            .buttonStyle(MediButtonStyle(colors: [.mediSuccess]))
                        }
                        if appointment.status == "confirmed" {
                            Button {
                                Task { await changeApptStatus(appointment, to: "in_progress") }
                            } label: {
                                Label("Iniciar consulta", systemImage: "play.circle.fill")
                            }
                            .buttonStyle(MediButtonStyle())
                        }
                        if appointment.status == "in_progress" {
                            Button {
                                Task { await changeApptStatus(appointment, to: "completed") }
                            } label: {
                                Label("Completar consulta", systemImage: "checkmark.seal.fill")
                            }
                            .buttonStyle(MediButtonStyle(colors: [.mediSuccess]))
                        }
                        if appointment.status != "cancelled" && appointment.status != "completed" {
                            Button {
                                Task { await changeApptStatus(appointment, to: "cancelled") }
                            } label: {
                                Label("Cancelar turno", systemImage: "xmark.circle.fill")
                            }
                            .buttonStyle(MediButtonStyle(isSecondary: true))
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Turno")
        .navigationBarTitleDisplayMode(.inline)
    }
    private func changeApptStatus(_ appointment: LocalAppointment, to newStatus: String) async {
        let apptId = appointment.remoteId?.uuidString ?? appointment.id.uuidString
        
        struct StatusReq: Encodable { let status: String; let cancelReason: String? }
        struct StatusResp: Decodable { let id: String; let status: String }
        
        do {
            let _: StatusResp = try await APIClient.shared.put(
                "/api/v1/appointments/\(apptId)/status",
                body: StatusReq(status: newStatus, cancelReason: newStatus == "cancelled" ? "Cancelado desde la app" : nil)
            )
            await MainActor.run {
                appointment.status = newStatus
                if newStatus == "cancelled" { appointment.cancelledAt = Date() }
                try? modelContext.save()
            }
        } catch {
            print("❌ Status change failed: \(error)")
        }
    }
}

struct NewAppointmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalPatient.lastName) private var patients: [LocalPatient]
    
    @State private var selectedPatient: LocalPatient?
    @State private var date = Date()
    @State private var startTime = Date()
    @State private var reason = ""
    @State private var isFirstVisit = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        VStack(spacing: 14) {
                            MediSectionHeader(title: "Paciente", icon: "person.fill")
                            Menu {
                                ForEach(patients) { p in
                                    Button(p.fullName) { selectedPatient = p }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundStyle(Color.mediPrimary)
                                    Text(selectedPatient?.fullName ?? "Seleccionar paciente")
                                        .foregroundStyle(selectedPatient == nil ? Color.mediTextMuted : Color.mediText)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(Color.mediPrimary)
                                }
                                .padding(16)
                                .background(Color.white.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.mediPrimary.opacity(0.15), lineWidth: 1)
                                )
                            }
                        }
                        .mediElevated(padding: 18)
                        
                        VStack(spacing: 14) {
                            MediSectionHeader(title: "Fecha y hora", icon: "calendar.badge.clock")
                            DatePicker("Fecha", selection: $date, displayedComponents: .date)
                                .tint(Color.mediPrimary)
                                .foregroundStyle(Color.mediText)
                            DatePicker("Hora", selection: $startTime, displayedComponents: .hourAndMinute)
                                .tint(Color.mediPrimary)
                                .foregroundStyle(Color.mediText)
                            Toggle("Primera visita", isOn: $isFirstVisit)
                                .tint(Color.mediCyan)
                                .foregroundStyle(Color.mediText)
                        }
                        .mediElevated(padding: 18)
                        
                        VStack(spacing: 14) {
                            MediSectionHeader(title: "Motivo", icon: "cross.case.fill")
                            MediTextField(icon: "text.alignleft", placeholder: "Motivo de la consulta", text: $reason)
                        }
                        .mediElevated(padding: 18)
                        
                        Button {
                            createAppointment()
                        } label: {
                            Label("Crear turno", systemImage: "calendar.badge.plus")
                        }
                        .buttonStyle(MediButtonStyle())
                        .disabled(selectedPatient == nil)
                        .opacity(selectedPatient == nil ? 0.6 : 1)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Nuevo turno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.mediPrimary)
                }
            }
        }
    }
    
    @State private var isSaving = false
    
    private func createAppointment() {
        guard let patient = selectedPatient else { return }
        isSaving = true
        
        Task {
            struct CreateApptReq: Encodable {
                let patientId: String
                let doctorId: String
                let date: String
                let startTime: String
                let endTime: String
                let reason: String?
                let isFirstVisit: Bool
            }
            struct CreateApptResp: Decodable { let id: String }
            
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            let tf = DateFormatter()
            tf.dateFormat = "HH:mm"
            
            let endTime = Calendar.current.date(byAdding: .minute, value: 30, to: startTime) ?? startTime
            let patientServerId = patient.remoteId?.uuidString ?? patient.id.uuidString
            
            let req = CreateApptReq(
                patientId: patientServerId,
                doctorId: "", // El backend lo toma del JWT
                date: f.string(from: date),
                startTime: tf.string(from: self.startTime),
                endTime: tf.string(from: endTime),
                reason: reason.isEmpty ? "Consulta" : reason,
                isFirstVisit: isFirstVisit
            )
            
            do {
                let resp: CreateApptResp = try await APIClient.shared.post("/api/v1/appointments", body: req)
                
                await MainActor.run {
                    let appt = LocalAppointment(doctorId: UUID(), patient: patient, date: date, startTime: self.startTime, endTime: endTime)
                    appt.remoteId = UUID(uuidString: resp.id)
                    appt.reason = reason.isEmpty ? "Consulta" : reason
                    appt.isFirstVisit = isFirstVisit
                    appt.syncStatus = .synced
                    modelContext.insert(appt)
                    try? modelContext.save()
                    dismiss()
                }
            } catch {
                await MainActor.run { isSaving = false }
            }
        }
    }
}

// MARK: - Reusable Empty State

struct EmptyStateMedi: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient.medi([.mediCyan.opacity(0.18), .mediSky.opacity(0.06)]))
                    .frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(LinearGradient.medi([.mediCyan, .mediSky]))
            }
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.mediText)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.mediTextSoft)
                .multilineTextAlignment(.center)
            
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus.circle.fill")
                }
                .buttonStyle(MediButtonStyle())
                .frame(maxWidth: 240)
                .padding(.top, 6)
            }
        }
        .padding(30)
    }
}
