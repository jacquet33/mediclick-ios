import SwiftUI

// MARK: - Waiting Room View (Sala de espera digital)

struct WaitingRoomView: View {
    @State private var todayAppointments: [WRAppointment] = []
    @State private var isLoading = true
    @State private var timer: Timer?
    
    private var confirmed: [WRAppointment] { todayAppointments.filter { $0.status == "confirmed" } }
    private var checkedIn: [WRAppointment] { todayAppointments.filter { $0.status == "checked_in" } }
    private var inProgress: [WRAppointment] { todayAppointments.filter { $0.status == "in_progress" } }
    private var completed: [WRAppointment] { todayAppointments.filter { $0.status == "completed" } }
    private var noShow: [WRAppointment] { todayAppointments.filter { $0.status == "no_show" } }
    
    var body: some View {
        ZStack {
            MediBackground()
            
            if isLoading {
                ProgressView().tint(.mediTeal)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Stats bar
                        HStack(spacing: 8) {
                            WRStatBubble(count: checkedIn.count, label: "En sala", color: .mediSuccess, icon: "person.fill.checkmark")
                            WRStatBubble(count: inProgress.count, label: "Atendiendo", color: .mediTeal, icon: "stethoscope")
                            WRStatBubble(count: confirmed.count, label: "Por llegar", color: .mediWarning, icon: "clock")
                            WRStatBubble(count: completed.count, label: "Atendidos", color: .mediTextMuted, icon: "checkmark.circle")
                        }
                        
                        // En atención actual
                        if let current = inProgress.first {
                            VStack(alignment: .leading, spacing: 10) {
                                MediSectionHeader(title: "Atendiendo ahora", icon: "stethoscope")
                                WRPatientCard(appointment: current, style: .inProgress) {
                                    Task { await updateStatus(current.id, "completed") }
                                }
                            }
                            .mediElevated()
                        }
                        
                        // En sala (checked in — physically present)
                        VStack(alignment: .leading, spacing: 10) {
                            MediSectionHeader(title: "En sala (\(checkedIn.count))", icon: "person.fill.checkmark")
                            
                            if checkedIn.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "chair.lounge")
                                        .font(.system(size: 28))
                                        .foregroundStyle(Color.mediTextMuted)
                                    Text("Nadie en la sala")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.mediTextSoft)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                            } else {
                                ForEach(Array(checkedIn.enumerated()), id: \.element.id) { idx, appt in
                                    WRPatientCard(appointment: appt, style: .waiting, position: idx + 1) {
                                        Task { await updateStatus(appt.id, "in_progress") }
                                    }
                                }
                            }
                        }
                        .mediElevated()
                        
                        // Confirmados (por llegar)
                        if !confirmed.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                MediSectionHeader(title: "Por llegar (\(confirmed.count))", icon: "clock")
                                ForEach(confirmed) { appt in
                                    WRPatientCard(appointment: appt, style: .confirmed) {
                                        Task { await updateStatus(appt.id, "checked_in") }
                                    }
                                }
                            }
                            .mediElevated()
                        }
                        
                        // Atendidos
                        if !completed.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                MediSectionHeader(title: "Atendidos (\(completed.count))", icon: "checkmark.circle.fill")
                                ForEach(completed) { appt in
                                    WRPatientCard(appointment: appt, style: .completed)
                                }
                            }
                            .mediElevated()
                        }
                        
                        // Ausentes
                        if !noShow.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                MediSectionHeader(title: "Ausentes (\(noShow.count))", icon: "person.slash")
                                ForEach(noShow) { appt in
                                    WRPatientCard(appointment: appt, style: .noShow)
                                }
                            }
                            .mediElevated()
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Sala de espera")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await load() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Color.mediPrimary)
                }
            }
        }
        .task {
            await load()
            // Auto-refresh cada 30 segundos
            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                Task { await load() }
            }
        }
        .onDisappear { timer?.invalidate() }
    }
    
    private func load() async {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: Date())
        
        do {
            let appts: [WRAppointment] = try await APIClient.shared.get(
                "/api/v1/appointments",
                query: ["date": today]
            )
            await MainActor.run {
                todayAppointments = appts.sorted { ($0.startTime ?? "") < ($1.startTime ?? "") }
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
    
    private func updateStatus(_ appointmentId: String, _ newStatus: String) async {
        struct StatusBody: Encodable { let status: String }
        do {
            let _: WRAppointment = try await APIClient.shared.put(
                "/api/v1/appointments/\(appointmentId)/status",
                body: StatusBody(status: newStatus)
            )
            await load()
        } catch { }
    }
}

// MARK: - Appointment Model for Waiting Room

struct WRAppointment: Decodable, Identifiable {
    let id: String
    let status: String
    let startTime: String?
    let endTime: String?
    let reason: String?
    let patientName: String?
    let isFirstVisit: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, status, reason
        case startTime = "start_time"
        case endTime = "end_time"
        case patientName = "patient_name"
        case isFirstVisit = "is_first_visit"
    }
    
    var timeFormatted: String {
        guard let st = startTime?.prefix(5) else { return "" }
        return String(st)
    }
}

// MARK: - Stat Bubble

struct WRStatBubble: View {
    let count: Int
    let label: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(color)
            }
            Text("\(count)")
                .font(.mediNumber(20))
                .foregroundStyle(Color.mediText)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.mediTextSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.mediSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: color.opacity(0.08), radius: 8, y: 3)
    }
}

// MARK: - Patient Card

enum WRCardStyle { case confirmed, waiting, inProgress, completed, noShow }

struct WRPatientCard: View {
    let appointment: WRAppointment
    let style: WRCardStyle
    var position: Int? = nil
    var onAction: (() -> Void)? = nil
    @State private var isActioning = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Position or status icon
            ZStack {
                let bg: Color = {
                    switch style {
                    case .confirmed: return .mediWarning
                    case .waiting: return .mediSuccess
                    case .inProgress: return .mediTeal
                    case .completed: return .mediTextMuted
                    case .noShow: return .mediDanger
                    }
                }()
                
                RoundedRectangle(cornerRadius: 10)
                    .fill(bg.opacity(0.12))
                    .frame(width: 40, height: 40)
                
                if let pos = position {
                    Text("\(pos)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(bg)
                } else {
                    Image(systemName: styleIcon)
                        .font(.system(size: 16))
                        .foregroundStyle(bg)
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(appointment.patientName ?? "Paciente")
                        .font(.mediCaption(14))
                        .foregroundStyle(Color.mediText)
                    if appointment.isFirstVisit == true {
                        Text("1ra vez")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.mediWarning)
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 8) {
                    Text(appointment.timeFormatted + " hs")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.mediTextSoft)
                    if let reason = appointment.reason, !reason.isEmpty {
                        Text("· \(reason)")
                            .font(.caption)
                            .foregroundStyle(Color.mediTextMuted)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Action button
            if let onAction, style == .confirmed || style == .waiting || style == .inProgress {
                Button {
                    isActioning = true
                    onAction()
                } label: {
                    if isActioning {
                        ProgressView()
                            .tint(actionColor)
                    } else {
                        Image(systemName: actionIcon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(actionColor)
                            .clipShape(Circle())
                            .shadow(color: actionColor.opacity(0.3), radius: 6, y: 2)
                    }
                }
                .disabled(isActioning)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var styleIcon: String {
        switch style {
        case .confirmed: return "clock"
        case .waiting: return "person.fill.checkmark"
        case .inProgress: return "stethoscope"
        case .completed: return "checkmark"
        case .noShow: return "person.slash"
        }
    }
    
    private var actionIcon: String {
        switch style {
        case .confirmed: return "person.badge.plus"    // Mark as arrived
        case .waiting: return "play.fill"               // Start consultation
        case .inProgress: return "checkmark"            // Complete
        default: return ""
        }
    }
    
    private var actionColor: Color {
        switch style {
        case .confirmed: return .mediSuccess
        case .waiting: return .mediTeal
        case .inProgress: return .mediSuccess
        default: return .mediTextMuted
        }
    }
}
