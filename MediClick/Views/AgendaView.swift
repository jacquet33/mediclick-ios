import SwiftUI
import SwiftData

struct AgendaView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalAppointment.startTime) private var appointments: [LocalAppointment]
    @State private var selectedDate = Date()
    @State private var showNewAppointment = false
    
    private var weekDates: [Date] {
        let cal = Calendar.current
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Week strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(weekDates, id: \.self) { date in
                            DayButton(date: date, isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate)) {
                                selectedDate = date
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(.gray.opacity(0.04))
                
                // Appointments list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if appointments.isEmpty {
                            ContentUnavailableView {
                                Label("Sin turnos", systemImage: "calendar.badge.minus")
                            } description: {
                                Text("No hay turnos para este día")
                            }
                            .frame(height: 300)
                        } else {
                            ForEach(appointments) { appt in
                                NavigationLink {
                                    AppointmentDetailView(appointment: appt)
                                } label: {
                                    AppointmentRow(appointment: appt)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Agenda")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewAppointment = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showNewAppointment) {
                NewAppointmentView()
            }
        }
    }
}

struct DayButton: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void
    
    private var dayName: String {
        date.formatted(.dateTime.weekday(.abbreviated)).capitalized
    }
    private var dayNumber: String {
        date.formatted(.dateTime.day())
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                Text(dayNumber)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(width: 44, height: 56)
            .background(isSelected ? .blue : .gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Appointment Detail

struct AppointmentDetailView: View {
    let appointment: LocalAppointment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section("Paciente") {
                if let patient = appointment.patient {
                    HStack {
                        MediAvatar(name: patient.fullName, size: 44)
                        VStack(alignment: .leading) {
                            Text(patient.fullName).font(.headline)
                            Text(patient.phone ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Turno") {
                LabeledContent("Fecha", value: appointment.date.formatted(date: .long, time: .omitted))
                LabeledContent("Hora", value: "\(appointment.formattedStartTime)")
                LabeledContent("Estado", value: appointment.status.capitalized)
                if let reason = appointment.reason {
                    LabeledContent("Motivo", value: reason)
                }
            }
            Section {
                if appointment.status == "pending" {
                    Button("Confirmar turno") {
                        appointment.status = "confirmed"
                        try? modelContext.save()
                    }
                    .foregroundStyle(Color.mediSuccess)
                }
                if appointment.status == "confirmed" {
                    Button("Iniciar consulta") {
                        appointment.status = "in_progress"
                        try? modelContext.save()
                    }
                    .foregroundStyle(Color.mediPrimary)
                }
                if appointment.status == "in_progress" {
                    Button("Completar consulta") {
                        appointment.status = "completed"
                        try? modelContext.save()
                    }
                    .foregroundStyle(Color.mediSuccess)
                }
                if appointment.status != "cancelled" && appointment.status != "completed" {
                    Button("Cancelar turno", role: .destructive) {
                        appointment.status = "cancelled"
                        appointment.cancelledAt = Date()
                        try? modelContext.save()
                    }
                }
            }
        }
        .navigationTitle("Detalle del turno")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - New Appointment

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
            Form {
                Section("Paciente") {
                    Picker("Seleccionar", selection: $selectedPatient) {
                        Text("Elegir paciente...").tag(nil as LocalPatient?)
                        ForEach(patients) { p in
                            Text(p.fullName).tag(p as LocalPatient?)
                        }
                    }
                }
                Section("Fecha y hora") {
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                    DatePicker("Hora", selection: $startTime, displayedComponents: .hourAndMinute)
                    Toggle("Primera visita", isOn: $isFirstVisit)
                }
                Section("Motivo") {
                    TextField("Motivo de la consulta", text: $reason, axis: .vertical)
                        .lineLimit(3)
                }
                Section {
                    Button("Crear turno") {
                        createAppointment()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(selectedPatient == nil)
                }
            }
            .navigationTitle("Nuevo turno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
    
    private func createAppointment() {
        guard let patient = selectedPatient else { return }
        let endTime = Calendar.current.date(byAdding: .minute, value: 30, to: startTime) ?? startTime
        let appt = LocalAppointment(
            doctorId: UUID(),
            patient: patient,
            date: date,
            startTime: startTime,
            endTime: endTime
        )
        appt.reason = reason
        appt.isFirstVisit = isFirstVisit
        modelContext.insert(appt)
        try? modelContext.save()
        dismiss()
    }
}
