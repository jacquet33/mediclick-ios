import SwiftUI
import SwiftData

// MARK: - Notifications View

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var auth

    @State private var notifications: [AppNotification] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else if notifications.isEmpty {
                    emptyState
                } else {
                    notificationList
                }
            }
            .navigationTitle("Notificaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Color.mediPrimary)
                }
                if !notifications.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Marcar leídas") { markAllRead() }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.mediPrimary)
                    }
                }
            }
            .task { await loadNotifications() }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient.medi([.mediCyan.opacity(0.12), .mediSky.opacity(0.08)]))
                    .frame(width: 80, height: 80)
                Image(systemName: "bell.slash")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(LinearGradient.medi([.mediPrimary, .mediDeep]))
            }
            Text("Sin notificaciones")
                .font(.mediTitle(18))
                .foregroundStyle(Color.mediText)
            Text("Cuando recibas nuevos turnos, mensajes o actualizaciones aparecerán acá.")
                .font(.mediCaption(13))
                .foregroundStyle(Color.mediTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Notification List

    private var notificationList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(notifications) { notif in
                    NavigationLink {
                        NotificationDetailView(notificationId: notif.id)
                    } label: {
                        notificationRow(notif)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { markAsRead(notif) })
                }
            }
            .padding(16)
        }
        .refreshable { await loadNotifications() }
    }

    private func notificationRow(_ notif: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(notif.isRead
                          ? Color.mediSurface
                          : LinearGradient.medi([.mediCyan.opacity(0.15), .mediSky.opacity(0.1)]).asColor)
                    .frame(width: 42, height: 42)
                Image(systemName: notif.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(notif.isRead ? Color.mediTextMuted : Color.mediPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(notif.title)
                    .font(.system(size: 14, weight: notif.isRead ? .regular : .semibold))
                    .foregroundStyle(Color.mediText)

                Text(notif.body)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.mediTextMuted)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let perfil = notif.perfil { PerfilBadge(perfil: perfil, compacto: true) }
                    Text(notif.timeAgo)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.mediTextMuted.opacity(0.7))
                }
            }

            Spacer()

            VStack(spacing: 10) {
                if !notif.isRead {
                    Circle()
                        .fill(Color.mediPrimary)
                        .frame(width: 8, height: 8)
                        .accessibilityLabel("Sin leer")
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.mediTextMuted)
            }
        }
        .contentShape(Rectangle())
        .padding(14)
        .background(notif.isRead ? Color.mediSurface.opacity(0.5) : Color.mediSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(notif.isRead ? Color.clear : Color.mediPrimary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Data Loading

    private func loadNotifications() async {
        isLoading = notifications.isEmpty

        do {
            struct NotifResponse: Decodable {
                let notifications: [AppNotification]
            }
            let orgDoctorId = auth.activeOrganization?.orgDoctorId ?? ""
            let response: NotifResponse = try await APIClient.shared.get(
                "/api/v1/notifications?orgDoctorId=\(orgDoctorId)"
            )
            await MainActor.run {
                notifications = response.notifications
                isLoading = false
            }
        } catch {
            // Si el endpoint no existe aún, mostrar vacío sin error
            await MainActor.run {
                notifications = []
                isLoading = false
            }
        }
    }

    private func markAsRead(_ notif: AppNotification) {
        guard !notif.isRead else { return }
        if let idx = notifications.firstIndex(where: { $0.id == notif.id }) {
            notifications[idx].isRead = true
        }
        Task {
            let _: EmptyResponse? = try? await APIClient.shared.put("/api/v1/notifications/\(notif.id)/read", body: EmptyBody())
        }
    }

    private func markAllRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        Task {
            let orgDoctorId = auth.activeOrganization?.orgDoctorId ?? ""
            let _: EmptyResponse? = try? await APIClient.shared.put("/api/v1/notifications/mark-all-read?orgDoctorId=\(orgDoctorId)", body: EmptyBody())
        }
    }
}

private struct EmptyBody: Encodable {}

// MARK: - Notification Model

struct AppNotification: Identifiable, Decodable {
    let id: String
    let title: String
    let body: String
    let category: String
    let createdAt: String
    var isRead: Bool
    var patientId: String?
    var appointmentId: String?
    var perfil: PerfilPaciente?

    var icon: String {
        switch category {
        case "NEW_APPOINTMENT", "appointment_reminder", "new_booking": return "calendar.badge.plus"
        case "BOOKING_REQUEST": return "clock.badge.questionmark"
        case "NEW_PATIENT": return "person.badge.plus"
        case "appointment_cancelled": return "calendar.badge.minus"
        case "new_message": return "message.fill"
        case "prescription_ready": return "doc.badge.plus"
        case "slot_released": return "calendar.badge.exclamationmark"
        default: return "bell.fill"
        }
    }

    var timeAgo: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: createdAt) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date2 = formatter.date(from: createdAt) else { return "" }
            return Self.relativeTime(from: date2)
        }
        return Self.relativeTime(from: date)
    }

    private static func relativeTime(from date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        switch diff {
        case ..<60: return "Ahora"
        case ..<3600: return "Hace \(Int(diff / 60)) min"
        case ..<86400: return "Hace \(Int(diff / 3600))h"
        case ..<604800: return "Hace \(Int(diff / 86400)) días"
        default:
            let f = DateFormatter()
            f.dateFormat = "d MMM"
            f.locale = Locale(identifier: "es_AR")
            return f.string(from: date)
        }
    }
}

// MARK: - Helper

private extension LinearGradient {
    var asColor: Color { Color.mediSurface } // fallback for conditional
}


// MARK: - Perfil del paciente (verde / amarillo / rojo)

struct PerfilPaciente: Decodable, Hashable {
    let estado: String      // verde | amarillo | rojo
    let faltan: [String]
    let nuevo: Bool?

    var color: Color {
        switch estado {
        case "verde": return .mediSuccess
        case "rojo": return .mediDanger
        default: return .mediWarning
        }
    }
    var fondo: Color {
        switch estado {
        case "verde": return .mediSuccessSoft
        case "rojo": return .mediDangerSoft
        default: return .mediWarningSoft
        }
    }
    var titulo: String {
        switch estado {
        case "verde": return "Perfil completo"
        case "rojo": return nuevo == true ? "Paciente nuevo sin datos" : "Faltan datos clave"
        default: return faltan.count == 1 ? "Falta 1 dato" : "Faltan \(faltan.count) datos"
        }
    }
}

struct PerfilBadge: View {
    let perfil: PerfilPaciente
    var compacto = false
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(perfil.color).frame(width: 7, height: 7)
            Text(perfil.titulo).font(.system(size: compacto ? 11 : 13, weight: .semibold))
        }
        .foregroundStyle(perfil.color)
        .padding(.horizontal, compacto ? 7 : 10).padding(.vertical, compacto ? 3 : 5)
        .background(perfil.fondo)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Detalle del aviso

struct NotificationDetailView: View {
    let notificationId: String
    @Query private var localPatients: [LocalPatient]
    @State private var detalle: Detalle?
    @State private var error: String?

    struct Detalle: Decodable {
        struct Turno: Decodable { let id: String; let fecha: String?; let hora: String?; let estado: String?; let motivo: String? }
        struct Paciente: Decodable {
            let id: String
            let firstName: String?
            let lastName: String?
            let dni: String?
            let dateOfBirth: String?
            let gender: String?
            let phone: String?
            let email: String?
            let insuranceProvider: String?
            let insurancePlan: String?
            let insuranceNumber: String?
            let address: String?
            let city: String?
            let turnos: Int?
            var nombre: String { [firstName, lastName].compactMap { $0 }.joined(separator: " ") }
        }
        let title: String
        let body: String
        let createdAt: String
        let turno: Turno?
        let paciente: Paciente?
        let perfil: PerfilPaciente?
        let linkCompletar: String?
    }

    var body: some View {
        ZStack {
            MediBackground()
            if let d = detalle {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(d.title).font(.system(size: 20, weight: .bold)).foregroundStyle(Color.mediText)
                            Text(d.body).font(.system(size: 14)).foregroundStyle(Color.mediTextSoft)
                        }
                        if let t = d.turno { turnoCard(t) }
                        if let p = d.paciente { pacienteCard(p, perfil: d.perfil, link: d.linkCompletar) }
                    }
                    .padding(16)
                }
            } else if let error {
                Text(error).foregroundStyle(Color.mediTextMuted).padding()
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Aviso")
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
    }

    private func cargar() async {
        do {
            detalle = try await APIClient.shared.get("/api/v1/notifications/\(notificationId)")
        } catch {
            self.error = "No se pudo cargar el aviso. Revisá la conexión."
        }
    }

    private func turnoCard(_ t: Detalle.Turno) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Turno", systemImage: "calendar").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.mediTextMuted)
            Text(fechaLarga(t.fecha) + (t.hora.map { " · \($0) hs" } ?? ""))
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.mediText)
            HStack(spacing: 8) {
                Text(estadoTurno(t.estado)).font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.mediTealSoft).foregroundStyle(Color.mediPrimary).clipShape(Capsule())
                if let m = t.motivo, !m.isEmpty { Text(m).font(.system(size: 13)).foregroundStyle(Color.mediTextSoft).lineLimit(2) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mediElevated()
    }

    @ViewBuilder
    private func pacienteCard(_ p: Detalle.Paciente, perfil: PerfilPaciente?, link: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Paciente", systemImage: "person").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.mediTextMuted)
                    Text(p.nombre).font(.system(size: 18, weight: .bold)).foregroundStyle(Color.mediText)
                    if let n = p.turnos { Text(n <= 1 ? "Primer turno" : "\(n) turnos").font(.system(size: 12)).foregroundStyle(Color.mediTextMuted) }
                }
                Spacer()
                if let perfil { PerfilBadge(perfil: perfil) }
            }

            VStack(spacing: 0) {
                fila("DNI", p.dni)
                fila("Nacimiento", p.dateOfBirth.map { fechaCorta($0) })
                fila("Teléfono", p.phone)
                fila("Email", p.email)
                fila("Cobertura", p.insuranceProvider.map { $0.isEmpty ? "Particular" : [$0, p.insurancePlan, p.insuranceNumber.map { "Nº \($0)" }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ") })
                fila("Domicilio", [p.address, p.city].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ").nilSiVacio)
            }
            .background(Color.mediBgSoft)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if let perfil, perfil.estado != "verde", !perfil.faltan.isEmpty {
                Text("Le falta: " + perfil.faltan.joined(separator: ", "))
                    .font(.system(size: 13)).foregroundStyle(perfil.color)
            }

            // Acciones
            if let perfil, perfil.estado != "verde", let tel = p.phone, !tel.isEmpty, let link {
                Button {
                    let msg = "Hola \(p.firstName ?? ""), para tu próxima consulta necesitamos que completes tus datos (DNI, fecha de nacimiento y cobertura médica). Te lleva 1 minuto: \(link)"
                    WhatsAppHelper.open(phone: tel, message: msg)
                } label: {
                    Label("Pedirle que complete sus datos", systemImage: "square.and.pencil")
                }
                .buttonStyle(MediButtonStyle())
            }
            HStack(spacing: 10) {
                if let tel = p.phone, !tel.isEmpty {
                    accion("WhatsApp", "message.fill") { WhatsAppHelper.open(phone: tel) }
                    accion("Llamar", "phone.fill") {
                        if let u = URL(string: "tel://" + tel.filter { $0.isNumber || $0 == "+" }) { UIApplication.shared.open(u) }
                    }
                }
                if let local = localPatients.first(where: { $0.remoteId?.uuidString.lowercased() == p.id.lowercased() }) {
                    NavigationLink { PatientDetailView(patient: local) } label: {
                        accionLabel("Ver ficha", "person.text.rectangle")
                    }
                }
            }
        }
        .mediElevated()
    }

    private func fila(_ t: String, _ v: String?) -> some View {
        HStack {
            Text(t).font(.system(size: 13)).foregroundStyle(Color.mediTextMuted)
            Spacer()
            if let v, !v.isEmpty {
                Text(v).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.mediText).multilineTextAlignment(.trailing)
            } else {
                Text("Sin cargar").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.mediDanger)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }

    private func accion(_ t: String, _ icono: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) { accionLabel(t, icono) }
    }

    private func accionLabel(_ t: String, _ icono: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icono).font(.system(size: 17))
            Text(t).font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Color.mediPrimary)
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Color.mediTealSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fechaLarga(_ iso: String?) -> String {
        guard let iso, let d = DateFormatter.dateOnly.date(from: iso) else { return iso ?? "" }
        let f = DateFormatter(); f.locale = Locale(identifier: "es_AR"); f.dateFormat = "EEEE d 'de' MMMM"
        return f.string(from: d).capitalized(with: Locale(identifier: "es_AR"))
    }
    private func fechaCorta(_ iso: String) -> String {
        guard let d = DateFormatter.dateOnly.date(from: iso) else { return iso }
        let f = DateFormatter(); f.locale = Locale(identifier: "es_AR"); f.dateFormat = "dd/MM/yyyy"
        return f.string(from: d)
    }
    private func estadoTurno(_ e: String?) -> String {
        switch e {
        case "confirmed": return "Confirmado"
        case "pending", "pending_approval": return "Pendiente"
        case "cancelled": return "Cancelado"
        case "completed": return "Atendido"
        case "no_show": return "Ausente"
        default: return e ?? "—"
        }
    }
}

private extension String {
    var nilSiVacio: String? { isEmpty ? nil : self }
}
