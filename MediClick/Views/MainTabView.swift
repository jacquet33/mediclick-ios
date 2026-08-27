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

            MoreView(selectedTab: $selectedTab)
                .tabItem { Label("Más", systemImage: "square.grid.2x2.fill") }
                .tag(4)
        }
        .tint(Color.mediPrimary)
    }
}

// MARK: - Más

/// iOS colapsa las pestañas en "More" cuando hay más de cinco, y eso
/// rompe la navegación interna. Con un menú propio controlamos el
/// comportamiento y además queda lugar para crecer.
struct MoreView: View {
    @Binding var selectedTab: Int
    @Environment(AuthManager.self) private var auth

    @State private var showProfile = false
    @State private var showBookingSettings = false
    @State private var showNotifications = false

    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Perfil
                        Button { showProfile = true } label: {
                            HStack(spacing: 14) {
                                if let data = auth.loadProfileImage(), let ui = UIImage(data: data) {
                                    Image(uiImage: ui)
                                        .resizable().scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(LinearGradient.mediHero, lineWidth: 2))
                                } else {
                                    MediAvatar(name: auth.fullName.isEmpty ? "Doctor" : auth.fullName, size: 56)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Dr. \(auth.fullName.isEmpty ? "Doctor" : auth.fullName)")
                                        .font(.mediHeadline(16))
                                        .foregroundStyle(Color.mediText)
                                    Text(auth.activeOrganization?.name ?? auth.specialty)
                                        .font(.caption)
                                        .foregroundStyle(Color.mediTextSoft)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Color.mediTextMuted)
                            }
                            .mediElevated(padding: 16)
                        }
                        .buttonStyle(.plain)

                        // Gestión
                        VStack(alignment: .leading, spacing: 4) {
                            MediSectionHeader(title: "Gestión", icon: "briefcase.fill")

                            NavigationLink {
                                ChatListView()
                            } label: {
                                MoreRow(icon: "message.fill", title: "Mensajes",
                                        subtitle: "Chat con pacientes", color: .mediSky)
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                WaitlistView()
                            } label: {
                                MoreRow(icon: "bell.badge.fill", title: "Lista de espera",
                                        subtitle: "Pacientes esperando turno", color: .mediCyan)
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                WaitingRoomView()
                            } label: {
                                MoreRow(icon: "chair.lounge.fill", title: "Sala de espera",
                                        subtitle: "Cola de atención en vivo", color: .mediSuccess)
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                RolesManagementView()
                            } label: {
                                MoreRow(icon: "person.3.fill", title: "Equipo y roles",
                                        subtitle: "Gestionar miembros", color: .mediDeep)
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                BillingView()
                            } label: {
                                MoreRow(icon: "banknote.fill", title: "Facturación",
                                        subtitle: "Lotes y nomencladores", color: .mediSuccess)
                            }
                            .buttonStyle(.plain)
                        }
                        .mediElevated(padding: 16)

                        // Configuración
                        VStack(alignment: .leading, spacing: 4) {
                            MediSectionHeader(title: "Configuración", icon: "gearshape.fill")

                            Button { showBookingSettings = true } label: {
                                MoreRow(icon: "link", title: "Reservas online",
                                        subtitle: "Tu enlace para pacientes", color: .mediCyan)
                            }
                            .buttonStyle(.plain)

                            Button { showNotifications = true } label: {
                                MoreRow(icon: "bell.fill", title: "Notificaciones",
                                        subtitle: "Alertas y recordatorios", color: .mediWarning)
                            }
                            .buttonStyle(.plain)
                        }
                        .mediElevated(padding: 16)

                        // Consultorios
                        if auth.organizations.count > 1 {
                            VStack(alignment: .leading, spacing: 10) {
                                MediSectionHeader(title: "Mis consultorios", icon: "building.2.fill")

                                ForEach(auth.organizations) { org in
                                    Button {
                                        auth.selectOrganization(org)
                                    } label: {
                                        HStack(spacing: 11) {
                                            Circle()
                                                .fill(auth.activeOrganization?.id == org.id
                                                      ? Color.mediSuccess : Color.mediTextMuted.opacity(0.3))
                                                .frame(width: 8, height: 8)
                                            Text(org.name)
                                                .font(.mediCaption(15))
                                                .foregroundStyle(Color.mediText)
                                            Spacer()
                                            if auth.activeOrganization?.id == org.id {
                                                Text("Activo")
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(Color.mediSuccess)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .mediElevated(padding: 16)
                        }

                        Button {
                            auth.logout()
                        } label: {
                            Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .buttonStyle(MediButtonStyle(isSecondary: true))
                        .padding(.top, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Más")
            .sheet(isPresented: $showProfile) { ProfileView() }
            .sheet(isPresented: $showBookingSettings) { BookingSettingsView() }
            .sheet(isPresented: $showNotifications) { NotificationsView() }
        }
    }
}

struct MoreRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient.medi([color.opacity(0.18), color.opacity(0.07)]))
                    .frame(width: 40, height: 40)
                    .shadow(color: color.opacity(0.2), radius: 4, y: 2)
                    .shadow(color: Color.black.opacity(0.04), radius: 1, y: 0.5)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.mediCaption(15))
                    .foregroundStyle(Color.mediText)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.mediTextSoft)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.mediTextMuted)
        }
        .padding(.vertical, 10)
    }
}
