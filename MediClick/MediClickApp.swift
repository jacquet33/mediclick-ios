import SwiftUI
import SwiftData

@main
struct MediClickApp: App {
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
            } else {
                LoginView()
                    .environment(authManager)
            }
        }
        .modelContainer(modelContainer)
    }
}
