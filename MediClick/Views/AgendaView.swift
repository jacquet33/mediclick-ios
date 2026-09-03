import SwiftUI
import SwiftData

// MARK: - AgendaView

struct AgendaView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalAppointment.startTime) private var appointments: [LocalAppointment]
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var calendarExpanded = true
    @State private var showNewAppointment = false
    @State private var monthTransitionDirection: Edge = .trailing
    
    private let calendar = Calendar.current
    
    private var dayAppointments: [LocalAppointment] {
        appointments.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    /// Fechas que tienen al menos un turno (para mostrar dots)
    private var datesWithAppointments: Set<DateComponents> {
        Set(appointments.map { calendar.dateComponents([.year, .month, .day], from: $0.date) })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                VStack(spacing: 0) {
                    // ─── Calendario ────────────────────────────
                    VStack(spacing: 0) {
                        monthHeader
                        weekdayLabels
                        
                        if calendarExpanded {
                            monthGrid
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            weekStrip
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .background(
                        Color.white.opacity(0.5)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                            )
                            .shadow(color: .mediPrimary.opacity(0.04), radius: 8, y: 4)
                            .padding(.horizontal, 8)
                    )
                    
                    // ─── Separador con fecha seleccionada ──────
                    selectedDateHeader
                    
                    // ─── Lista de turnos ───────────────────────
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            if dayAppointments.isEmpty {
                                EmptyStateMedi(
                                    icon: "calendar.badge.plus",
                                    title: "Sin turnos",
                                    subtitle: "No hay turnos para este día",
                                    actionTitle: "Agendar turno"
                                ) { showNewAppointment = true }
                                .padding(.top, 40)
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
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Agenda")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Botón Hoy
                        if !calendar.isDateInToday(selectedDate) {
                            Button {
                                withAnimation(.spring(response: 0.35)) {
                                    selectedDate = Date()
                                    displayedMonth = Date()
                                }
                            } label: {
                                Text("Hoy")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.mediCyan)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.mediCyan.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        
                        // Botón nuevo turno
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
                
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            calendarExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: calendarExpanded ? "chevron.up.circle" : "chevron.down.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.mediPrimary.opacity(0.6))
                    }
                }
            }
            .sheet(isPresented: $showNewAppointment) { NewAppointmentView() }
        }
    }
    
    // MARK: - Month Header (< Septiembre 2026 >)
    
    private var monthHeader: some View {
        HStack {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.mediPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.mediPrimary.opacity(0.08))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text(monthYearString(from: displayedMonth))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.mediText)
                .contentTransition(.numericText())
            
            Spacer()
            
            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.mediPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.mediPrimary.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Weekday Labels (Lun Mar Mié ...)
    
    private var weekdayLabels: some View {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        let reordered: [String] = {
            var r: [String] = []
            for i in 0..<7 { r.append(symbols[(start + i) % 7]) }
            return r
        }()
        
        return HStack(spacing: 0) {
            ForEach(reordered, id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.mediTextMuted)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 6)
    }
    
    // MARK: - Month Grid (calendario completo)
    
    private var monthGrid: some View {
        let days = generateMonthDays(for: displayedMonth)
        let rows = days.chunked(into: 7)
        
        return VStack(spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        if let date = day {
                            CalendarDayCell(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                isToday: calendar.isDateInToday(date),
                                isCurrentMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month),
                                hasAppointments: datesWithAppointments.contains(
                                    calendar.dateComponents([.year, .month, .day], from: date)
                                )
                            ) {
                                withAnimation(.spring(response: 0.25)) {
                                    selectedDate = date
                                }
                            }
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 40)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 8)
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        changeMonth(by: 1)
                    } else if value.translation.width > 50 {
                        changeMonth(by: -1)
                    }
                }
        )
    }
    
    // MARK: - Week Strip (vista compacta - solo semana actual)
    
    private var weekStrip: some View {
        let weekDates = currentWeekDates()
        
        return HStack(spacing: 6) {
            ForEach(weekDates, id: \.self) { date in
                CalendarDayCell(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(date),
                    isCurrentMonth: true,
                    hasAppointments: datesWithAppointments.contains(
                        calendar.dateComponents([.year, .month, .day], from: date)
                    )
                ) {
                    withAnimation(.spring(response: 0.25)) {
                        selectedDate = date
                    }
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Selected Date Header
    
    private var selectedDateHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 13))
                .foregroundStyle(Color.mediCyan)
            
            Text(selectedDateString)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.mediText)
            
            if !dayAppointments.isEmpty {
                Text("·")
                    .foregroundStyle(Color.mediTextMuted)
                Text("\(dayAppointments.count) turno\(dayAppointments.count == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.mediCyan)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Helpers
    
    private func changeMonth(by value: Int) {
        withAnimation(.spring(response: 0.35)) {
            if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
                displayedMonth = newMonth
            }
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_AR")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date).capitalized
    }
    
    private var selectedDateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_AR")
        f.dateFormat = "EEEE d 'de' MMMM"
        return f.string(from: selectedDate).capitalized
    }
    
    private func currentWeekDates() -> [Date] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start else {
            return []
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }
    
    /// Generar días del mes incluyendo días vacíos al inicio para alinear columnas
    private func generateMonthDays(for month: Date) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }
        
        // Calcular offset: cuántos días en blanco antes del día 1
        var weekday = calendar.component(.weekday, from: firstDay)
        // Ajustar para que lunes = 0
        let firstWeekday = calendar.firstWeekday
        var offset = (weekday - firstWeekday + 7) % 7
        
        var days: [Date?] = Array(repeating: nil, count: offset)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        // Rellenar la última semana para completar la grilla
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
}

// MARK: - CalendarDayCell

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let hasAppointments: Bool
    let action: () -> Void
    
    private var dayNumber: String {
        Calendar.current.component(.day, from: date).description
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(dayNumber)
                    .font(.system(size: 15, weight: isSelected || isToday ? .bold : .medium, design: .rounded))
                    .foregroundStyle(dayTextColor)
                
                // Dot indicator
                Circle()
                    .fill(hasAppointments
                          ? (isSelected ? .white : Color.mediCyan)
                          : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                Group {
                    if isSelected {
                        LinearGradient.mediHero
                            .clipShape(Circle())
                    } else if isToday {
                        Circle()
                            .stroke(Color.mediCyan, lineWidth: 1.5)
                    }
                }
                .frame(width: 38, height: 38)
            )
        }
        .buttonStyle(.plain)
        .opacity(isCurrentMonth ? 1.0 : 0.3)
    }
    
    private var dayTextColor: Color {
        if isSelected { return .white }
        if !isCurrentMonth { return Color.mediTextMuted }
        if isToday { return Color.mediCyan }
        return Color.mediText
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - DayChip (kept for backward compatibility)

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

// MARK: - Appointment Detail

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
                                Label("Finalizar consulta", systemImage: "checkmark.seal.fill")
                            }
                            .buttonStyle(MediButtonStyle(colors: [.mediSuccess]))
                        }
                        if appointment.status != "cancelled" && appointment.status != "completed" {
                            Button {
                                Task { await changeApptStatus(appointment, to: "cancelled") }
                            } label: {
                                Label("Cancelar turno", systemImage: "xmark.circle")
                            }
                            .buttonStyle(MediButtonStyle(isSecondary: true))
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .navigationTitle("Turno")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func changeApptStatus(_ appt: LocalAppointment, to status: String) async {
        struct StatusUpdate: Encodable { let status: String }
        do {
            let _: EmptyResponse = try await APIClient.shared.put(
                "/api/v1/appointments/\(appt.remoteId?.uuidString ?? "")/status",
                body: StatusUpdate(status: status)
            )
            await MainActor.run {
                appt.status = status
                try? modelContext.save()
            }
        } catch {
            // silently fail
        }
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
