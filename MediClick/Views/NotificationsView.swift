import SwiftUI

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
                    notificationRow(notif)
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

                Text(notif.timeAgo)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.mediTextMuted.opacity(0.7))
            }

            Spacer()

            if !notif.isRead {
                Circle()
                    .fill(Color.mediPrimary)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(14)
        .background(notif.isRead ? Color.mediSurface.opacity(0.5) : Color.mediSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(notif.isRead ? Color.clear : Color.mediPrimary.opacity(0.15), lineWidth: 1)
        )
        .onTapGesture { markAsRead(notif) }
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
            try? await APIClient.shared.put("/api/v1/notifications/\(notif.id)/read", body: EmptyBody())
        }
    }

    private func markAllRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        Task {
            let orgDoctorId = auth.activeOrganization?.orgDoctorId ?? ""
            try? await APIClient.shared.put("/api/v1/notifications/mark-all-read?orgDoctorId=\(orgDoctorId)", body: EmptyBody())
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

    var icon: String {
        switch category {
        case "NEW_APPOINTMENT", "appointment_reminder": return "calendar.badge.plus"
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
