import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem { Label("Inicio", systemImage: "heart.text.clipboard") }
                .tag(0)
            
            AgendaView()
                .tabItem { Label("Agenda", systemImage: "calendar.badge.clock") }
                .tag(1)
            
            PatientsView()
                .tabItem { Label("Pacientes", systemImage: "person.2.fill") }
                .tag(2)
            
            PrescriptionsView()
                .tabItem { Label("Recetas", systemImage: "cross.case.fill") }
                .tag(3)
            
            ChatListView()
                .tabItem { Label("Chat", systemImage: "message.fill") }
                .tag(4)
        }
        .tint(Color.mediPrimary)
    }
}
