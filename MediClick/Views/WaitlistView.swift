import SwiftUI

// MARK: - API Models

struct WaitlistEntry: Decodable, Identifiable {
    let id: String
    let patientId: String?
    let contactName: String?
    let contactPhone: String?
    let contactEmail: String?
    let desiredDate: String
    let preferredStartTime: String?
    let preferredEndTime: String?
    let reason: String?
    let status: String
    let priority: Int
    let notifiedAt: String?
    let notifiedSlotTime: String?
    let createdAt: String
    let patientName: String?
    let patientPhone: String?
    
    enum CodingKeys: String, CodingKey {
        case id, status, priority, reason
        case patientId = "patient_id"
        case contactName = "contact_name"
        case contactPhone = "contact_phone"
        case contactEmail = "contact_email"
        case desiredDate = "desired_date"
        case preferredStartTime = "preferred_start_time"
        case preferredEndTime = "preferred_end_time"
        case notifiedAt = "notified_at"
        case notifiedSlotTime = "notified_slot_time"
        case createdAt = "created_at"
        case patientName = "patient_name"
        case patientPhone = "patient_phone"
    }
    
    var displayName: String { contactName ?? patientName ?? "Sin nombre" }
    var displayPhone: String { contactPhone ?? patientPhone ?? "" }
    
    var dateFormatted: String {
        let parts = desiredDate.prefix(10).split(separator: "-")
        guard parts.count == 3 else { return desiredDate }
        return "\(parts[2])/\(parts[1])/\(parts[0])"
    }
    
    var timeRange: String? {
        guard let start = preferredStartTime?.prefix(5) else { return nil }
        if let end = preferredEndTime?.prefix(5) {
            return "\(start) - \(end)"
        }
        return "Desde \(start)"
    }
}

struct WaitlistStats: Decodable {
    let waiting: Int
    let notified: Int
    let booked: Int
    let expired: Int
    let waitingToday: Int
    let waitingTomorrow: Int
    
    enum CodingKeys: String, CodingKey {
        case waiting, notified, booked, expired
        case waitingToday = "waiting_today"
        case waitingTomorrow = "waiting_tomorrow"
    }
}

struct AddWaitlistRequest: Encodable {
    let patientId: String?
    let contactName: String
    let contactPhone: String
    let contactEmail: String?
    let desiredDate: String
    let preferredStartTime: String?
    let preferredEndTime: String?
    let reason: String?
    let priority: Int?
}

struct BookFromWaitlistRequest: Encodable {
    let startTime: String
    let endTime: String
}

// MARK: - Waitlist Main View

struct WaitlistView: View {
    @State private var entries: [WaitlistEntry] = []
    @State private var stats: WaitlistStats?
    @State private var isLoading = true
    @State private var filterDate: Date = Date()
    @State private var showAllDates = true
    @State private var showAddSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                if isLoading {
                    ProgressView().tint(.mediPrimary)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            statsBar
                            filterBar
                            entriesList
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Lista de espera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: {
                        ZStack {
                            Circle().fill(LinearGradient.mediHero).frame(width: 34, height: 34)
                            Image(systemName: "plus").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        }
                        .shadow(color: .mediCyan.opacity(0.4), radius: 8, y: 3)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddToWaitlistView { Task { await load() } }
            }
            .task { await load() }
        }
    }
    
    // MARK: - Stats
    
    private var statsBar: some View {
        HStack(spacing: 10) {
            WLStatPill(value: stats?.waiting ?? 0, label: "Esperando", color: .mediCyan)
            WLStatPill(value: stats?.notified ?? 0, label: "Notificados", color: .mediWarning)
            WLStatPill(value: stats?.booked ?? 0, label: "Reservados", color: .mediSuccess)
        }
    }
    
    // MARK: - Filter
    
    private var filterBar: some View {
        HStack(spacing: 8) {
            FilterChip(label: "Todos", isActive: showAllDates) {
                showAllDates = true
                Task { await load() }
            }
            FilterChip(label: "Hoy", isActive: !showAllDates && Calendar.current.isDateInToday(filterDate)) {
                showAllDates = false
                filterDate = Date()
                Task { await load() }
            }
            FilterChip(label: "Mañana", isActive: !showAllDates && Calendar.current.isDateInTomorrow(filterDate)) {
                showAllDates = false
                filterDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                Task { await load() }
            }
            Spacer()
        }
    }
    
    // MARK: - List
    
    private var entriesList: some View {
        VStack(spacing: 10) {
            if entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.mediTextMuted)
                    Text("No hay pacientes en espera")
                        .font(.mediBody())
                        .foregroundStyle(Color.mediTextSoft)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(entries) { entry in
                    WaitlistEntryCard(entry: entry) {
                        Task { await load() }
                    }
                }
            }
        }
    }
    
    // MARK: - Load
    
    private func load() async {
        let dateParam = showAllDates ? "" : "?date=\(formatISO(filterDate))"
        
        async let entriesReq: [WaitlistEntry] = APIClient.shared.get("/api/v1/waitlist\(dateParam)")
        async let statsReq: WaitlistStats = APIClient.shared.get("/api/v1/waitlist/stats")
        
        do {
            let (e, s) = try await (entriesReq, statsReq)
            await MainActor.run {
                entries = e
                stats = s
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
    
    private func formatISO(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

// MARK: - Stat Pill

struct WLStatPill: View {
    let value: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.mediNumber(20))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.mediTextSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? .white : Color.mediTextSoft)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isActive
                    ? Color.mediTeal
                    : Color.mediSurface
                )
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isActive ? Color.clear : Color.mediCyan.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Entry Card

struct WaitlistEntryCard: View {
    let entry: WaitlistEntry
    var onChanged: (() -> Void)?
    @State private var isDeleting = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                MediAvatar(name: entry.displayName, size: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayName)
                        .font(.mediHeadline(15))
                        .foregroundStyle(Color.mediText)
                    if !entry.displayPhone.isEmpty {
                        Text(entry.displayPhone)
                            .font(.caption)
                            .foregroundStyle(Color.mediTextSoft)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    statusBadge
                    Text(entry.dateFormatted)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.mediTextMuted)
                }
            }
            
            HStack(spacing: 12) {
                if let range = entry.timeRange {
                    Label(range, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(Color.mediCyan)
                }
                if let reason = entry.reason, !reason.isEmpty {
                    Label(reason, systemImage: "text.quote")
                        .font(.caption)
                        .foregroundStyle(Color.mediTextSoft)
                        .lineLimit(1)
                }
            }
            
            if entry.status == "waiting" || entry.status == "notified" {
                HStack(spacing: 8) {
                    if let phone = entry.contactPhone ?? entry.patientPhone, !phone.isEmpty {
                        Link(destination: URL(string: "tel:\(phone)")!) {
                            Label("Llamar", systemImage: "phone.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.mediSuccess)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.mediSuccess.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        Task { await cancel() }
                    } label: {
                        if isDeleting {
                            ProgressView().tint(.mediDanger)
                        } else {
                            Label("Quitar", systemImage: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.mediDanger)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.mediDanger.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    .disabled(isDeleting)
                }
            }
        }
        .mediElevated()
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        let (label, color): (String, Color) = {
            switch entry.status {
            case "waiting": return ("Esperando", .mediCyan)
            case "notified": return ("Notificado", .mediWarning)
            case "booked": return ("Reservado", .mediSuccess)
            case "expired": return ("Expirado", .mediTextMuted)
            case "cancelled": return ("Cancelado", .mediDanger)
            default: return (entry.status, .mediTextMuted)
            }
        }()
        MediBadge(label, color: color)
    }
    
    private func cancel() async {
        isDeleting = true
        do {
            let _: WaitlistEntry = try await APIClient.shared.delete("/api/v1/waitlist/\(entry.id)")
            onChanged?()
        } catch {
            isDeleting = false
        }
    }
}

// MARK: - Add to Waitlist Sheet

struct AddToWaitlistView: View {
    @Environment(\.dismiss) private var dismiss
    
    var onAdded: (() -> Void)?
    
    @State private var contactName = ""
    @State private var contactPhone = ""
    @State private var desiredDate = Date()
    @State private var useTimeRange = false
    @State private var startTime = "08:00"
    @State private var endTime = "12:00"
    @State private var reason = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient.medi([.mediCyan, .mediSky]))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "bell.badge.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white)
                            }
                            .shadow(color: .mediCyan.opacity(0.3), radius: 10, y: 4)
                            
                            Text("Agregar a lista de espera")
                                .font(.mediHeadline(17))
                                .foregroundStyle(Color.mediText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            MediSectionHeader(title: "Paciente", icon: "person.fill")
                            MediTextField(label: "Nombre completo *", icon: "person", placeholder: "Ej: María Rodríguez", text: $contactName)
                            MediTextField(label: "Celular *", icon: "phone", placeholder: "3447-412345", text: $contactPhone)
                        }
                        .mediElevated()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            MediSectionHeader(title: "¿Cuándo?", icon: "calendar")
                            
                            DatePicker("Fecha deseada", selection: $desiredDate, in: Date()..., displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .tint(.mediPrimary)
                            
                            Toggle(isOn: $useTimeRange) {
                                Label("Franja horaria específica", systemImage: "clock")
                                    .font(.mediCaption(14))
                            }
                            .tint(.mediCyan)
                            
                            if useTimeRange {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Desde")
                                            .font(.mediCaption(12))
                                            .foregroundStyle(Color.mediTextSoft)
                                        Picker("Desde", selection: $startTime) {
                                            ForEach(timeOptions, id: \.self) { t in
                                                Text(t).tag(t)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(.mediPrimary)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Hasta")
                                            .font(.mediCaption(12))
                                            .foregroundStyle(Color.mediTextSoft)
                                        Picker("Hasta", selection: $endTime) {
                                            ForEach(timeOptions, id: \.self) { t in
                                                Text(t).tag(t)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(.mediPrimary)
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .mediElevated()
                        .animation(.easeInOut(duration: 0.2), value: useTimeRange)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            MediSectionHeader(title: "Motivo", icon: "text.quote")
                            MediTextField(label: "Motivo de consulta", icon: "text.alignleft", placeholder: "Opcional", text: $reason)
                        }
                        .mediElevated()
                        
                        Button {
                            Task { await save() }
                        } label: {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Label("Agregar a la lista", systemImage: "bell.badge.fill")
                            }
                        }
                        .buttonStyle(MediButtonStyle())
                        .disabled(contactName.isEmpty || contactPhone.isEmpty || isSaving)
                        .opacity(contactName.isEmpty || contactPhone.isEmpty ? 0.5 : 1)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Lista de espera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color.mediPrimary)
                }
            }
        }
    }
    
    private var timeOptions: [String] {
        stride(from: 7, through: 21, by: 1).flatMap { h in
            ["\(String(format: "%02d", h)):00", "\(String(format: "%02d", h)):30"]
        }
    }
    
    private func save() async {
        isSaving = true
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        
        let req = AddWaitlistRequest(
            patientId: nil,
            contactName: contactName,
            contactPhone: contactPhone,
            contactEmail: nil,
            desiredDate: f.string(from: desiredDate),
            preferredStartTime: useTimeRange ? startTime : nil,
            preferredEndTime: useTimeRange ? endTime : nil,
            reason: reason.isEmpty ? nil : reason,
            priority: nil
        )
        
        do {
            let _: WaitlistEntry = try await APIClient.shared.post("/api/v1/waitlist", body: req)
            await MainActor.run {
                onAdded?()
                dismiss()
            }
        } catch {
            await MainActor.run { isSaving = false }
        }
    }
}
