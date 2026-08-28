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
            await MainActor.run { isAuthorized = granted }
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            print("Push permission error: \(error)")
        }
    }
    
    /// Llamado desde AppDelegate cuando se recibe el token
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        self.deviceToken = token
        print("📱 APNs Token: \(token)")
        
        // Enviar al backend
        Task { await uploadToken(token) }
    }
    
    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("❌ Push registration failed: \(error)")
    }
    
    /// Subir token al backend
    private func uploadToken(_ token: String) async {
        guard let userId = UserDefaults.standard.string(forKey: "doctor_id")
                ?? UserDefaults.standard.string(forKey: "user_id") else { return }
        
        let userType = UserDefaults.standard.string(forKey: "user_type") ?? "doctor"
        let device = UIDevice.current
        
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
            token: token,
            platform: "ios",
            deviceName: device.name,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            osVersion: device.systemVersion
        )
        
        do {
            struct OkResponse: Decodable { let ok: Bool }
            let _: OkResponse = try await APIClient.shared.post("/api/v1/push/register", body: body)
            print("✅ Push token uploaded")
        } catch {
            print("❌ Failed to upload push token: \(error)")
        }
    }
    
    /// Desregistrar al hacer logout
    func unregister() async {
        guard let token = deviceToken else { return }
        
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
        
        UNUserNotificationCenter.current().setNotificationCategories([
            appointmentCategory, messageCategory, cancelledCategory, prescriptionCategory,
        ])
    }
}
