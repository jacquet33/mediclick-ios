import SwiftUI

// MARK: - Schedule View (Doctor Availability Configuration)

struct ScheduleView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var weekSchedules: [DaySchedule] = DaySchedule.defaultWeek()
    @State private var exceptions: [ScheduleException] = []
    @State private var showAddException = false
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showSaved = false

    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()

                if isLoading {
                    ProgressView()
                        .tint(Color.mediTeal)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {

                            // ─── Header Info ───
                            VStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(LinearGradient.medi([.mediTeal, .mediCyan]))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "clock.badge.checkmark.fill")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(.white)
                                }

                                Text("Horarios de atención")
                                    .font(.mediHeadline(17))
                                    .foregroundStyle(Color.mediText)

                                Text("Configurá qué días y horarios atendés. Tus pacientes verán estos horarios al reservar.")
                                    .font(.caption)
                                    .foregroundStyle(Color.mediTextSoft)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 8)
                            }
                            .padding(.vertical, 8)

                            // ─── Weekly Schedule ───
                            VStack(alignment: .leading, spacing: 4) {
                                MediSectionHeader(title: "Semana", icon: "calendar")

                                ForEach($weekSchedules) { $day in
                                    DayRow(day: $day)
                                }
                            }
                            .mediElevated(padding: 18)

                            // ─── Slot Config ───
                            VStack(alignment: .leading, spacing: 14) {
                                MediSectionHeader(title: "Duración de turnos", icon: "timer")

                                let activeDays = weekSchedules.filter(\.isActive)

                                if activeDays.isEmpty {
                                    HStack {
                                        Image(systemName: "info.circle")
                                            .foregroundStyle(Color.mediTextMuted)
                                        Text("Activá al menos un día para configurar la duración")
                                            .font(.caption)
                                            .foregroundStyle(Color.mediTextSoft)
                                    }
                                    .padding(.vertical, 8)
                                } else {
                                    ForEach($weekSchedules) { $day in
                                        if day.isActive {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text(day.dayName)
                                                    .font(.mediCaption(13))
                                                    .foregroundStyle(Color.mediTextSoft)
                                                    .textCase(.uppercase)

                                                HStack {
                                                    Text("Duración")
                                                        .font(.subheadline)
                                                        .foregroundStyle(Color.mediText)
                                                    Spacer()
                                                    Text("\(day.slotDuration) min")
                                                        .font(.mediHeadline(15))
                                                        .foregroundStyle(Color.mediTeal)
                                                    Stepper("", value: $day.slotDuration, in: 10...120, step: 5)
                                                        .labelsHidden()
                                                        .tint(Color.mediTeal)
                                                }

                                                HStack {
                                                    Text("Pacientes/turno")
                                                        .font(.subheadline)
                                                        .foregroundStyle(Color.mediText)
                                                    Spacer()
                                                    Text("\(day.maxPatients)")
                                                        .font(.mediHeadline(15))
                                                        .foregroundStyle(Color.mediTeal)
                                                    Stepper("", value: $day.maxPatients, in: 1...10, step: 1)
                                                        .labelsHidden()
                                                        .tint(Color.mediTeal)
                                                }

                                                if day.dayOfWeek != weekSchedules.filter(\.isActive).last?.dayOfWeek {
                                                    Divider().overlay(Color.mediTeal.opacity(0.1))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .mediElevated(padding: 18)

                            // ─── Exceptions ───
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    MediSectionHeader(title: "Excepciones", icon: "calendar.badge.exclamationmark")
                                    Spacer()
                                    Button {
                                        showAddException = true
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundStyle(Color.mediTeal)
                                    }
                                }

                                if exceptions.isEmpty {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle")
                                            .foregroundStyle(Color.mediSuccess)
                                        Text("Sin excepciones programadas")
                                            .font(.caption)
                                            .foregroundStyle(Color.mediTextSoft)
                                    }
                                    .padding(.vertical, 8)
                                } else {
                                    ForEach(exceptions) { exc in
                                        ExceptionRow(exception: exc) {
                                            Task { await deleteException(exc.id) }
                                        }
                                    }
                                }
                            }
                            .mediElevated(padding: 18)

                            // ─── Save Button ───
                            Button {
                                Task { await save() }
                            } label: {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else if showSaved {
                                    Label("Guardado ✓", systemImage: "checkmark.circle.fill")
                                } else {
                                    Label("Guardar horarios", systemImage: "checkmark.circle.fill")
                                }
                            }
                            .buttonStyle(MediButtonStyle())
                            .disabled(isSaving)
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Mis horarios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Color.mediTeal)
                }
            }
            .task { await load() }
            .sheet(isPresented: $showAddException) {
                AddExceptionSheet { exc in
                    Task { await addException(exc) }
                }
            }
        }
    }

    // MARK: - API

    private func load() async {
        defer { Task { @MainActor in isLoading = false } }

        let doctorId = auth.doctorId
        guard !doctorId.isEmpty else { return }

        // Load schedules
        do {
            let schedules: [APISchedule] = try await APIClient.shared.get(
                "/api/v1/schedules?doctor_id=\(doctorId)"
            )
            await MainActor.run {
                for schedule in schedules {
                    if let idx = weekSchedules.firstIndex(where: { $0.dayOfWeek == schedule.dayOfWeek }) {
                        weekSchedules[idx].isActive = true
                        weekSchedules[idx].startTime = parseTime(schedule.startTime)
                        weekSchedules[idx].endTime = parseTime(schedule.endTime)
                        weekSchedules[idx].slotDuration = schedule.slotDurationMinutes ?? 30
                        weekSchedules[idx].maxPatients = schedule.maxPatientsPerSlot ?? 1
                    }
                }
            }
        } catch {
            print("Failed to load schedules: \(error)")
        }

        // Load exceptions
        do {
            let excs: [APIException] = try await APIClient.shared.get(
                "/api/v1/schedules/exceptions?doctor_id=\(doctorId)"
            )
            await MainActor.run {
                exceptions = excs.map { exc in
                    ScheduleException(
                        id: exc.id,
                        date: exc.date,
                        isAvailable: exc.isAvailable ?? false,
                        startTime: exc.startTime,
                        endTime: exc.endTime,
                        reason: exc.reason
                    )
                }
            }
        } catch {
            print("Failed to load exceptions: \(error)")
        }
    }

    private func save() async {
        let doctorId = auth.doctorId
        guard !doctorId.isEmpty else { return }

        await MainActor.run { isSaving = true }

        let activeDays = weekSchedules.filter(\.isActive)
        let payload = SetSchedulePayload(
            doctorId: doctorId,
            schedules: activeDays.map { day in
                ScheduleEntry(
                    dayOfWeek: day.dayOfWeek,
                    startTime: formatTime(day.startTime),
                    endTime: formatTime(day.endTime),
                    slotDurationMinutes: day.slotDuration,
                    maxPatientsPerSlot: day.maxPatients
                )
            }
        )

        do {
            struct Resp: Decodable { let message: String }
            let _: Resp = try await APIClient.shared.put("/api/v1/schedules", body: payload)
            await MainActor.run {
                isSaving = false
                showSaved = true
            }
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run { showSaved = false }
        } catch {
            await MainActor.run { isSaving = false }
            print("Failed to save schedules: \(error)")
        }
    }

    private func addException(_ exc: NewException) async {
        let doctorId = auth.doctorId
        guard !doctorId.isEmpty else { return }

        let payload = AddExceptionPayload(
            doctorId: doctorId,
            date: exc.dateString,
            isAvailable: exc.isAvailable,
            startTime: exc.isAvailable ? exc.startTime : nil,
            endTime: exc.isAvailable ? exc.endTime : nil,
            reason: exc.reason.isEmpty ? nil : exc.reason
        )

        do {
            let created: APIException = try await APIClient.shared.post(
                "/api/v1/schedules/exceptions", body: payload
            )
            await MainActor.run {
                exceptions.append(ScheduleException(
                    id: created.id,
                    date: created.date,
                    isAvailable: created.isAvailable ?? false,
                    startTime: created.startTime,
                    endTime: created.endTime,
                    reason: created.reason
                ))
                exceptions.sort { $0.date < $1.date }
            }
        } catch {
            print("Failed to add exception: \(error)")
        }
    }

    private func deleteException(_ id: String) async {
        do {
            struct Resp: Decodable { let message: String }
            let _: Resp = try await APIClient.shared.delete("/api/v1/schedules/exceptions/\(id)")
            await MainActor.run {
                exceptions.removeAll { $0.id == id }
            }
        } catch {
            print("Failed to delete exception: \(error)")
        }
    }

    // MARK: - Helpers

    private func parseTime(_ timeStr: String) -> Date {
        let parts = timeStr.prefix(5).split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]) else { return defaultTime(8, 0) }
        return defaultTime(h, m)
    }

    private func defaultTime(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    }

    private func formatTime(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 8, c.minute ?? 0)
    }
}

// MARK: - Day Row Component

struct DayRow: View {
    @Binding var day: DaySchedule

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Day toggle
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        day.isActive.toggle()
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(day.isActive
                                  ? LinearGradient.medi([.mediTeal, .mediCyan])
                                  : LinearGradient.medi([.mediTextMuted.opacity(0.12), .mediTextMuted.opacity(0.06)]))
                            .frame(width: 42, height: 42)
                        Text(day.shortName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(day.isActive ? .white : Color.mediTextMuted)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(day.dayName)
                        .font(.mediCaption(15))
                        .foregroundStyle(day.isActive ? Color.mediText : Color.mediTextMuted)

                    if day.isActive {
                        Text("\(formatDisplay(day.startTime)) – \(formatDisplay(day.endTime))")
                            .font(.caption)
                            .foregroundStyle(Color.mediTeal)
                    } else {
                        Text("No atendés")
                            .font(.caption)
                            .foregroundStyle(Color.mediTextMuted)
                    }
                }

                Spacer()

                if day.isActive {
                    // Time pickers
                    VStack(spacing: 4) {
                        DatePicker("", selection: $day.startTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .scaleEffect(0.85)
                        DatePicker("", selection: $day.endTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .scaleEffect(0.85)
                    }
                }
            }
            .padding(.vertical, 8)

            if day.dayOfWeek < 6 {
                Divider().overlay(Color.mediTeal.opacity(0.06))
            }
        }
    }

    private func formatDisplay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Exception Row

struct ExceptionRow: View {
    let exception: ScheduleException
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(exception.isAvailable
                          ? Color.mediSuccessSoft
                          : Color.mediDangerSoft)
                    .frame(width: 42, height: 42)
                Image(systemName: exception.isAvailable ? "clock.badge.checkmark" : "calendar.badge.minus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(exception.isAvailable ? Color.mediSuccess : Color.mediDanger)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(exception.date))
                    .font(.mediCaption(15))
                    .foregroundStyle(Color.mediText)

                if exception.isAvailable, let start = exception.startTime, let end = exception.endTime {
                    Text("Horario especial: \(start.prefix(5)) – \(end.prefix(5))")
                        .font(.caption)
                        .foregroundStyle(Color.mediSuccess)
                } else {
                    Text(exception.reason ?? "Día libre")
                        .font(.caption)
                        .foregroundStyle(Color.mediDanger)
                }
            }

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.mediDanger)
            }
        }
        .padding(.vertical, 6)
    }

    private func formatDate(_ dateStr: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: String(dateStr.prefix(10))) else { return dateStr }
        let output = DateFormatter()
        output.dateFormat = "EEE d MMM"
        output.locale = Locale(identifier: "es_AR")
        return output.string(from: date).capitalized
    }
}

// MARK: - Add Exception Sheet

struct AddExceptionSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var isAvailable = false
    @State private var startTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var endTime = Calendar.current.date(from: DateComponents(hour: 13, minute: 0)) ?? Date()
    @State private var reason = ""

    let onSave: (NewException) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {

                        // Type selector
                        VStack(alignment: .leading, spacing: 14) {
                            MediSectionHeader(title: "Tipo", icon: "questionmark.circle.fill")

                            HStack(spacing: 10) {
                                ExceptionTypeButton(
                                    icon: "calendar.badge.minus",
                                    title: "Día libre",
                                    subtitle: "No atendés este día",
                                    isSelected: !isAvailable,
                                    color: .mediDanger
                                ) {
                                    withAnimation { isAvailable = false }
                                }

                                ExceptionTypeButton(
                                    icon: "clock.badge.checkmark",
                                    title: "Horario especial",
                                    subtitle: "Cambiás el horario",
                                    isSelected: isAvailable,
                                    color: .mediSuccess
                                ) {
                                    withAnimation { isAvailable = true }
                                }
                            }
                        }
                        .mediElevated(padding: 18)

                        // Date
                        VStack(alignment: .leading, spacing: 14) {
                            MediSectionHeader(title: "Fecha", icon: "calendar")

                            DatePicker("Seleccionar día", selection: $date, in: Date()..., displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .tint(Color.mediTeal)
                        }
                        .mediElevated(padding: 18)

                        // Special hours
                        if isAvailable {
                            VStack(alignment: .leading, spacing: 14) {
                                MediSectionHeader(title: "Horario", icon: "clock.fill")

                                HStack {
                                    Text("Desde")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.mediText)
                                    Spacer()
                                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                }

                                HStack {
                                    Text("Hasta")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.mediText)
                                    Spacer()
                                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                }
                            }
                            .mediElevated(padding: 18)
                        }

                        // Reason
                        if !isAvailable {
                            VStack(alignment: .leading, spacing: 14) {
                                MediSectionHeader(title: "Motivo (opcional)", icon: "text.bubble")
                                MediTextField(icon: "pencil", placeholder: "Ej: Congreso, vacaciones...", text: $reason)
                            }
                            .mediElevated(padding: 18)
                        }

                        Button {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            let timeFormatter = DateFormatter()
                            timeFormatter.dateFormat = "HH:mm"

                            onSave(NewException(
                                dateString: formatter.string(from: date),
                                isAvailable: isAvailable,
                                startTime: isAvailable ? timeFormatter.string(from: startTime) : nil,
                                endTime: isAvailable ? timeFormatter.string(from: endTime) : nil,
                                reason: reason
                            ))
                            dismiss()
                        } label: {
                            Label(isAvailable ? "Agregar horario especial" : "Agregar día libre",
                                  systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(MediButtonStyle())
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Nueva excepción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color.mediTeal)
                }
            }
        }
    }
}

struct ExceptionTypeButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected
                              ? LinearGradient.medi([color, color.opacity(0.7)])
                              : LinearGradient.medi([.mediTextMuted.opacity(0.12), .mediTextMuted.opacity(0.06)]))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Color.mediTextMuted)
                }

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.mediText : Color.mediTextMuted)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.mediTextSoft)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(isSelected ? color.opacity(0.06) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Models

struct DaySchedule: Identifiable {
    let id = UUID()
    let dayOfWeek: Int
    var isActive: Bool
    var startTime: Date
    var endTime: Date
    var slotDuration: Int
    var maxPatients: Int

    var dayName: String {
        let names = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]
        return names[dayOfWeek]
    }

    var shortName: String {
        let shorts = ["DO", "LU", "MA", "MI", "JU", "VI", "SA"]
        return shorts[dayOfWeek]
    }

    static func defaultWeek() -> [DaySchedule] {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
        let end = cal.date(from: DateComponents(hour: 12, minute: 0)) ?? Date()

        return (0...6).map { day in
            DaySchedule(
                dayOfWeek: day,
                isActive: (1...5).contains(day), // Lunes a Viernes activos por default
                startTime: start,
                endTime: end,
                slotDuration: 30,
                maxPatients: 1
            )
        }
    }
}

struct ScheduleException: Identifiable {
    let id: String
    let date: String
    let isAvailable: Bool
    let startTime: String?
    let endTime: String?
    let reason: String?
}

struct NewException {
    let dateString: String
    let isAvailable: Bool
    let startTime: String?
    let endTime: String?
    let reason: String
}

// MARK: - API Models

struct APISchedule: Decodable {
    let id: String?
    let dayOfWeek: Int
    let startTime: String
    let endTime: String
    let slotDurationMinutes: Int?
    let maxPatientsPerSlot: Int?

    // CodingKeys removed — APIClient.decoder uses .convertFromSnakeCase
}

struct APIException: Decodable {
    let id: String
    let date: String
    let isAvailable: Bool?
    let startTime: String?
    let endTime: String?
    let reason: String?
    // CodingKeys removed — APIClient.decoder uses .convertFromSnakeCase
}

struct SetSchedulePayload: Encodable {
    let doctorId: String
    let schedules: [ScheduleEntry]
}

struct ScheduleEntry: Encodable {
    let dayOfWeek: Int
    let startTime: String
    let endTime: String
    let slotDurationMinutes: Int
    let maxPatientsPerSlot: Int
}

struct AddExceptionPayload: Encodable {
    let doctorId: String
    let date: String
    let isAvailable: Bool
    let startTime: String?
    let endTime: String?
    let reason: String?
}
