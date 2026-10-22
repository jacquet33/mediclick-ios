import SwiftUI
import UserNotifications
import UIKit

// MARK: - Push Notification Manager

@Observable
final class PushManager: NSObject {
    static let shared = PushManager()
    
    var isAuthorized = false
    var deviceToken: String?
    
    private override init() {
        super.init()
    }
    
    /// Solicitar permiso de notificaciones
    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                isAuthorized = granted
                print("🔔 Push permission granted: \(granted)")
            }
            if granted {
                await MainActor.run {
                    print("🔔 Calling registerForRemoteNotifications...")
                    UIApplication.shared.registerForRemoteNotifications()
                }
                // Wait a bit for the APNs callback to fire
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        } catch {
            print("❌ Push permission error: \(error)")
        }
    }

    /// Llamado desde AppDelegate cuando se recibe el token
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        self.deviceToken = token
        print("📱 APNs Token received: \(token.prefix(20))...")

        // Enviar al backend
        Task { await uploadToken(token) }
    }
    
    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("❌ Push registration failed: \(error)")
    }
    
    /// Subir token al backend — reintentar si doctor_id aún no está disponible
    @MainActor
    func uploadToken(_ token: String? = nil) async {
        let tok = token ?? deviceToken
        guard let tok else {
            print("⚠️ Push: no device token available yet")
            return
        }

        // Intentar obtener userId — si no está, reintentar hasta 5 veces con delay
        var userId: String?
        for attempt in 1...5 {
            userId = UserDefaults.standard.string(forKey: "doctor_id")
                ?? UserDefaults.standard.string(forKey: "user_id")
            if userId != nil { break }
            print("⏳ Push: doctor_id not available yet, retry \(attempt)/5...")
            try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000) // 1s, 2s, 3s...
        }

        guard let userId else {
            print("❌ Push: doctor_id never became available — token NOT uploaded")
            return
        }

        let userType = UserDefaults.standard.string(forKey: "user_type") ?? "doctor"
        let deviceName = UIDevice.current.name
        let osVersion = UIDevice.current.systemVersion

        struct RegisterBody: Encodable {
            let userType: String
            let userId: String
            let token: String
            let platform: String
            let deviceName: String
            let appVersion: String
            let osVersion: String
        }

        let body = RegisterBody(
            userType: userType,
            userId: userId,
            token: tok,
            platform: "ios",
            deviceName: deviceName,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            osVersion: osVersion
        )

        do {
            struct OkResponse: Decodable { let ok: Bool }
            let _: OkResponse = try await APIClient.shared.post("/api/v1/push/register", body: body)
            print("✅ Push token uploaded for userId=\(userId)")
        } catch {
            print("❌ Failed to upload push token: \(error)")
        }
    }
    
    /// Desregistrar al hacer logout
    func unregister() async {
        guard deviceToken != nil else { return }
        
        struct UnregBody: Encodable { let token: String }
        do {
            struct OkResponse: Decodable { let ok: Bool }
            let _: OkResponse = try await APIClient.shared.delete("/api/v1/push/unregister")
            print("✅ Push token unregistered")
        } catch {
            print("❌ Failed to unregister push token: \(error)")
        }
    }
}

// MARK: - Notification Categories & Actions

extension PushManager {
    func setupCategories() {
        let viewAction = UNNotificationAction(identifier: "VIEW", title: "Ver", options: .foreground)
        let dismissAction = UNNotificationAction(identifier: "DISMISS", title: "Descartar", options: .destructive)
        
        let appointmentCategory = UNNotificationCategory(
            identifier: "appointment_reminder",
            actions: [viewAction, dismissAction],
            intentIdentifiers: []
        )
        
        let messageCategory = UNNotificationCategory(
            identifier: "new_message",
            actions: [viewAction],
            intentIdentifiers: []
        )
        
        let cancelledCategory = UNNotificationCategory(
            identifier: "appointment_cancelled",
            actions: [viewAction],
            intentIdentifiers: []
        )
        
        let prescriptionCategory = UNNotificationCategory(
            identifier: "prescription_ready",
            actions: [viewAction],
            intentIdentifiers: []
        )

        let newBookingCategory = UNNotificationCategory(
            identifier: "NEW_APPOINTMENT",
            actions: [viewAction],
            intentIdentifiers: []
        )

        let bookingRequestCategory = UNNotificationCategory(
            identifier: "BOOKING_REQUEST",
            actions: [viewAction],
            intentIdentifiers: []
        )

        let newPatientCategory = UNNotificationCategory(
            identifier: "NEW_PATIENT",
            actions: [viewAction],
            intentIdentifiers: []
        )

        let slotReleasedCategory = UNNotificationCategory(
            identifier: "slot_released",
            actions: [viewAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            appointmentCategory, messageCategory, cancelledCategory, prescriptionCategory,
            newBookingCategory, bookingRequestCategory, newPatientCategory, slotReleasedCategory,
        ])
    }
}
