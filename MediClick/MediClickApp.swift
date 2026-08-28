import SwiftUI
import SwiftData
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
                    }
            } else {
                LoginView()
                    .environment(authManager)
            }
        }
        .modelContainer(modelContainer)
    }
}
