import SwiftUI
import SwiftData
import UIKit
import UserNotifications

// MARK: - AppDelegate for Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        PushManager.shared.setupCategories()
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushManager.shared.didFailToRegisterForRemoteNotifications(error: error)
    }
    
    // Notificación recibida en foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .badge, .sound]
    }
    
    // Usuario tocó la notificación
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        let category = response.notification.request.content.categoryIdentifier
        print("📲 Push tapped: category=\(category) data=\(userInfo)")
        // TODO: navegar a la pantalla correspondiente
    }
}

@main
struct MediClickApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    let modelContainer: ModelContainer
    @State private var authManager = AuthManager()
    
    init() {
        // ── Navigation bar appearance ──────────────────────────
        let tinta = UIColor(red: 0x16/255, green: 0x19/255, blue: 0x25/255, alpha: 1) // #161925
        let crema = UIColor(red: 0xFF/255, green: 0xF7/255, blue: 0xF3/255, alpha: 1) // #FFF7F3
        let textSoft = UIColor(red: 0x5A/255, green: 0x5D/255, blue: 0x6D/255, alpha: 1) // #5A5D6D

        // Large title (scrolled to top)
        let largeTitleAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: tinta,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold),
        ]
        // Inline title (scrolled)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: tinta,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
        ]

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = crema
        navAppearance.largeTitleTextAttributes = largeTitleAttrs
        navAppearance.titleTextAttributes = titleAttrs

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = tinta

        // ── Search bar placeholder color ───────────────────────
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).attributedPlaceholder =
            NSAttributedString(string: " ", attributes: [.foregroundColor: textSoft])
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).textColor = tinta

        // ── SwiftData ──────────────────────────────────────────
        do {
            let schema = Schema([
                LocalDoctor.self,
                LocalPatient.self,
                LocalAppointment.self,
                LocalMedicalRecord.self,
                LocalPrescription.self,
                LocalPrescriptionItem.self,
                LocalConversation.self,
                LocalMessage.self,
                LocalNotification.self,
            ])
            let config = ModelConfiguration("MediClick", schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                MainTabView()
                    .environment(authManager)
                    .task {
                        // Pedir permiso de push al loguearse
                        await PushManager.shared.requestPermission()
                        // Re-upload token in case it arrived before login completed
                        await PushManager.shared.uploadToken()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: APIError.sessionExpiredNotification)) { _ in
                        // Sesión expirada → volver al login sin mostrar errores
                        authManager.logout()
                    }
            } else {
                LoginView()
                    .environment(authManager)
            }
        }
        .modelContainer(modelContainer)
    }
}
